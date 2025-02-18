!==============================================================================!
  subroutine Compute_Turbulent(flow, sol, dt, ini, phi, n_step)
!------------------------------------------------------------------------------!
!   Discretizes and solves transport equations for different turbulent         !
!   variables.                                                                 !
!------------------------------------------------------------------------------!
!---------------------------------[Modules]------------------------------------!
  use Field_Mod
  use Les_Mod
  use Rans_Mod
  use Comm_Mod
  use Var_Mod,      only: Var_Type
  use Grid_Mod,     only: Grid_Type
  use Grad_Mod,     only: Grad_Mod_Variable
  use Info_Mod,     only: Info_Mod_Iter_Fill_At
  use Numerics_Mod
  use Solver_Mod,   only: Solver_Type, Bicg, Cg, Cgs
  use Matrix_Mod,   only: Matrix_Type
!------------------------------------------------------------------------------!
  implicit none
!--------------------------------[Arguments]-----------------------------------!
  type(Field_Type),  target :: flow
  type(Solver_Type), target :: sol
  real                      :: dt
  integer                   :: ini
  type(Var_Type)            :: phi
  integer                   :: n_step
!----------------------------------[Locals]------------------------------------!
  type(Grid_Type),   pointer :: grid
  type(Var_Type),    pointer :: u, v, w
  real,              pointer :: flux(:)
  type(Matrix_Type), pointer :: a
  real,              pointer :: b(:)
  integer                    :: s, c, c1, c2, exec_iter
  real                       :: f_ex, f_im
  real                       :: phis
  real                       :: a0, a12, a21
  real                       :: vis_eff
  real                       :: phi_x_f, phi_y_f, phi_z_f
!==============================================================================!
!                                                                              !
!  The form of equations which are solved:                                     !
!                                                                              !
!     /               /                /                     /                 !
!    |     dphi      |                | mu_eff              |                  !
!    | rho ---- dV + | rho u phi dS = | ------ DIV phi dS + | G dV             !
!    |      dt       |                |  sigma              |                  !
!   /               /                /                     /                   !
!                                                                              !
!------------------------------------------------------------------------------!

  ! Take aliases
  grid => flow % pnt_grid
  flux => flow % flux
  u    => flow % u
  v    => flow % v
  w    => flow % w
  a    => sol  % a
  b    => sol  % b % val

  ! Initialize matrix and right hand side
  a % val(:) = 0.0
  b      (:) = 0.0

  ! Old values (o) and older than old (oo)
  if(ini .eq. 1) then
    do c = 1, grid % n_cells
      phi % oo(c) = phi % o(c)
      phi % o (c) = phi % n(c)
    end do
  end if

  ! Gradients
  call Grad_Mod_Variable(phi, .true.)

  !---------------!
  !               !
  !   Advection   !
  !               !
  !---------------!
  call Numerics_Mod_Advection_Term(phi, 1.0, flux, sol,  &
                                   phi % x,              &
                                   phi % y,              &
                                   phi % z,              &
                                   grid % dx,            &
                                   grid % dy,            &
                                   grid % dz)

  !------------------!
  !                  !
  !     Difusion     !
  !                  !
  !------------------!

  !----------------------------!
  !   Spatial discretization   !
  !----------------------------!
  do s = 1, grid % n_faces

    c1 = grid % faces_c(1,s)
    c2 = grid % faces_c(2,s)

    vis_eff = viscosity + (    grid % fw(s)  * vis_t(c1)         &
                        + (1.0-grid % fw(s)) * vis_t(c2))        &
                        / phi % sigma

    if(turbulence_model .eq. SPALART_ALLMARAS .or.               &
       turbulence_model .eq. DES_SPALART)                        &
      vis_eff = viscosity + (    grid % fw(s)  * vis % n(c1)     &
                          + (1.0-grid % fw(s)) * vis % n(c2))    &
                          / phi % sigma

    if(turbulence_model .eq. HYBRID_LES_RANS) then
      vis_eff = viscosity + (    grid % fw(s)  * vis_t_eff(c1)   &
                          + (1.0-grid % fw(s)) * vis_t_eff(c2))  &
                          / phi % sigma
    end if
    phi_x_f = grid % fw(s) * phi % x(c1) + (1.0-grid % fw(s)) * phi % x(c2)
    phi_y_f = grid % fw(s) * phi % y(c1) + (1.0-grid % fw(s)) * phi % y(c2)
    phi_z_f = grid % fw(s) * phi % z(c1) + (1.0-grid % fw(s)) * phi % z(c2)

    if(turbulence_model .eq. K_EPS_ZETA_F    .or.  &
       turbulence_model .eq. HYBRID_LES_RANS .or.  &
       turbulence_model .eq. K_EPS) then
      if(c2 < 0 .and. phi % name .eq. 'KIN') then
        if(Grid_Mod_Bnd_Cond_Type(grid,c2) .eq. WALL .or.  &
           Grid_Mod_Bnd_Cond_Type(grid,c2) .eq. WALLFL) then
          if(y_plus(c1) > 4) then

            phi_x_f = 0.0
            phi_y_f = 0.0
            phi_z_f = 0.0
            vis_eff = 0.0

          end if
        end if
      end if
    end if

    ! Total (exact) diffusive flux
    f_ex = vis_eff * (  phi_x_f * grid % sx(s)  &
                      + phi_y_f * grid % sy(s)  &
                      + phi_z_f * grid % sz(s) )

    a0 = vis_eff * a % fc(s)

    ! Implicit diffusive flux
    f_im = (  phi_x_f * grid % dx(s)                      &
            + phi_y_f * grid % dy(s)                      &
            + phi_z_f * grid % dz(s) ) * a0

    ! Cross diffusion part
    phi % c(c1) = phi % c(c1) + f_ex - f_im
    if(c2  > 0) then
      phi % c(c2) = phi % c(c2) - f_ex + f_im
    end if

    ! Compute coefficients for the sysytem matrix
    a12 = a0
    a21 = a0

    a12 = a12  - min(flux(s), real(0.0))
    a21 = a21  + max(flux(s), real(0.0))

    ! Fill the system matrix
    if(c2  > 0) then
      a % val(a % pos(1,s)) = a % val(a % pos(1,s)) - a12
      a % val(a % dia(c1))  = a % val(a % dia(c1))  + a12
      a % val(a % pos(2,s)) = a % val(a % pos(2,s)) - a21
      a % val(a % dia(c2))  = a % val(a % dia(c2))  + a21
    else if(c2  < 0) then

      ! Outflow is not included because it was causing problems
      if((Grid_Mod_Bnd_Cond_Type(grid,c2) .eq. INFLOW)  .or.   &
         (Grid_Mod_Bnd_Cond_Type(grid,c2) .eq. WALL)    .or.   &
         (Grid_Mod_Bnd_Cond_Type(grid,c2) .eq. PRESSURE).or.   &
         (Grid_Mod_Bnd_Cond_Type(grid,c2) .eq. CONVECT) .or.   &
         (Grid_Mod_Bnd_Cond_Type(grid,c2) .eq. WALLFL) ) then
        a % val(a % dia(c1)) = a % val(a % dia(c1)) + a12
        b(c1) = b(c1) + a12 * phi % n(c2)
      end if
    end if

  end do  ! through faces

  ! Cross diffusion terms are treated explicity
  do c = 1, grid % n_cells
    b(c) = b(c) + phi % c(c)
  end do

  !--------------------!
  !                    !
  !   Inertial terms   !
  !                    !
  !--------------------!
  call Numerics_Mod_Inertial_Term(phi, density, sol, dt)

  !-------------------------------------!
  !                                     !
  !   Source terms and wall function    !
  !                                     !
  !-------------------------------------!
  if(turbulence_model .eq. K_EPS) then
    if(phi % name .eq. 'KIN') call Source_Kin_K_Eps(flow, sol)
    if(phi % name .eq. 'EPS') call Source_Eps_K_Eps(flow, sol)
  end if

  if(turbulence_model .eq. K_EPS_ZETA_F .or.  &
     turbulence_model .eq. HYBRID_LES_RANS) then
    if(phi % name .eq. 'KIN')  call Source_Kin_K_Eps_Zeta_F(flow, sol)
    if(phi % name .eq. 'EPS')  call Source_Eps_K_Eps_Zeta_F(flow, sol)
    if(phi % name .eq. 'ZETA') call Source_Zeta_K_Eps_Zeta_F(flow, sol, n_step)
  end if

  if( (turbulence_model .eq. K_EPS_ZETA_F .and. heat_transfer) .or. &
      (turbulence_model .eq. HYBRID_LES_RANS .and. heat_transfer) ) then
    if(phi % name .eq. 'T2')  call Source_T2(flow, sol)
  end if

  if(turbulence_model .eq. SPALART_ALLMARAS .or.  &
     turbulence_model .eq. DES_SPALART) then
    call Source_Vis_Spalart_Almaras(grid, sol, phi % x, phi % y, phi % z)
  end if

  !---------------------------------!
  !                                 !
  !   Solve the equations for phi   !
  !                                 !
  !---------------------------------!

  ! Under-relax the equations
  call Numerics_Mod_Under_Relax(phi, sol)

  ! Call linear solver to solve the equations
  call Bicg(sol,            &
            phi % n,        &
            b,              &
            phi % precond,  &
            phi % niter,    &
            exec_iter,      &
            phi % tol,      &
            phi % res)

  do c = 1, grid % n_cells
    if( phi % n(c) < 0.0 ) phi % n(c) = phi % o(c)
    if(phi % name .eq. 'ZETA')  phi % n(c) = min(phi % n(c), 1.8)
  end do

  ! Print info on the screen
  if(turbulence_model .eq. K_EPS        .or.  &
     turbulence_model .eq. K_EPS_ZETA_F .or.  &
     turbulence_model .eq. HYBRID_LES_RANS) then
    if(phi % name .eq. 'KIN')  &
      call Info_Mod_Iter_Fill_At(3, 1, phi % name, exec_iter, phi % res)
    if(phi % name .eq. 'EPS')  &
      call Info_Mod_Iter_Fill_At(3, 2, phi % name, exec_iter, phi % res)
    if(phi % name .eq. 'ZETA')  &
      call Info_Mod_Iter_Fill_At(3, 3, phi % name, exec_iter, phi % res)
  end if

  if( (turbulence_model .eq. K_EPS_ZETA_F .and. heat_transfer) .or. &
      (turbulence_model .eq. HYBRID_LES_RANS .and. heat_transfer) ) then
    if(phi % name .eq. 'T2')  &
      call Info_Mod_Iter_Fill_At(3, 5, phi % name, exec_iter, phi % res)
  end if

  call Comm_Mod_Exchange_Real(grid, phi % n)

  end subroutine
