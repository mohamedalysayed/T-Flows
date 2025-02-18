!==============================================================================!
  subroutine Compute_Scalar(flow, sol, dt, ini, sc)
!------------------------------------------------------------------------------!
!   Purpose: Solve transport equation for use scalar.                          !
!------------------------------------------------------------------------------!
!----------------------------------[Modules]-----------------------------------!
  use Const_Mod
  use Field_Mod,    only: Field_Type, diffusivity, density
  use Rans_Mod
  use Comm_Mod
  use Var_Mod
  use Grid_Mod
  use Grad_Mod
  use Info_Mod
  use Numerics_Mod
  use Solver_Mod,   only: Solver_Type, Bicg, Cg, Cgs
  use Matrix_Mod,   only: Matrix_Type
  use Control_Mod
  use User_Mod
  use Work_Mod,     only: phi_x       => r_cell_01,  &
                          phi_y       => r_cell_02,  &
                          phi_z       => r_cell_03,  &
                          u1uj_phij   => r_cell_06,  &
                          u2uj_phij   => r_cell_07,  &
                          u3uj_phij   => r_cell_08,  &
                          u1uj_phij_x => r_cell_09,  &
                          u2uj_phij_y => r_cell_10,  &
                          u3uj_phij_z => r_cell_11
!------------------------------------------------------------------------------!
  implicit none
!-----------------------------------[Arguments]--------------------------------!
  type(Field_Type),  target :: flow
  type(Solver_Type), target :: sol
  real                      :: dt
  integer                   :: ini
  integer                   :: sc
!----------------------------------[Calling]-----------------------------------!
! real :: Turbulent_Prandtl_Number
!-----------------------------------[Locals]-----------------------------------!
  type(Grid_Type),   pointer :: grid
  type(Matrix_Type), pointer :: a
  real,              pointer :: b(:)
  real,              pointer :: flux(:)
  type(Var_Type),    pointer :: phi
  integer                    :: n, c, s, c1, c2, row, col, exec_iter
  real                       :: a0, a12, a21
  real                       :: ns
  real                       :: dif_eff1, f_ex1, f_im1
  real                       :: dif_eff2, f_ex2, f_im2
  real                       :: phix_f1, phiy_f1, phiz_f1
  real                       :: phix_f2, phiy_f2, phiz_f2
  real                       :: phis, sc_t1, sc_t2
  character(len=80)          :: name
!------------------------------------------------------------------------------!
!
!  The form of equations which are solved:
!
!     /                /                /
!    |     d phi      |                |
!    | rho ----- dV   | rho u phi dS = | gamma DIV phi dS
!    |      dt        |                |
!   /                /                /
!
!==============================================================================!

  ! Take aliases
  grid => flow % pnt_grid
  flux => flow % flux
  a    => sol % a
  b    => sol % b % val
  phi  => flow % scalar(sc)

  do n = 1, a % row(grid % n_cells+1) ! to je broj nonzero + 1
    a % val(n) = 0.0
  end do
  a % val = 0.0

  b(:) = 0.0

  !-------------------------------------!
  !   Initialize variables and fluxes   !
  !-------------------------------------!

  ! Old values (o and oo)
  if(ini.lt.2) then
    do c = 1, grid % n_cells
      phi % oo(c) = phi % o(c)
      phi % o (c) = phi % n(c)
    end do
  end if

  ! Gradients
  call Grad_Mod_Component(grid, phi % n, 1, phi_x, .true.)
  call Grad_Mod_Component(grid, phi % n, 2, phi_y, .true.)
  call Grad_Mod_Component(grid, phi % n, 3, phi_z, .true.)

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

  !--------------!
  !              !
  !   Difusion   !
  !              !
  !--------------!

  !----------------------------!
  !   Spatial discretization   !
  !----------------------------!
  call Control_Mod_Turbulent_Schmidt_Number(sc_t)  ! get default sc_t (0.9)

  do s = 1, grid % n_faces

    c1 = grid % faces_c(1,s)
    c2 = grid % faces_c(2,s)

!   For species, we don't have a function for turbulent Schmidt number
!   if(turbulence_model .ne. LES_SMAGORINSKY .or.  &
!      turbulence_model .ne. LES_DYNAMIC     .or.  &
!      turbulence_model .ne. LES_WALE        .or.  &
!      turbulence_model .ne. DNS) then
!     sc_t1 = Turbulent_Prandtl_Number(grid, c1)
!     sc_t2 = Turbulent_Prandtl_Number(grid, c2)
!     sc_t  = grid % fw(s) * sc_t1 + (1.0-grid % fw(s)) * sc_t2
!   end if

    ! Gradients on the cell face 
    if(c2 > 0) then
      phix_f1 = grid % fw(s)*phi_x(c1) + (1.0-grid % fw(s))*phi_x(c2)
      phiy_f1 = grid % fw(s)*phi_y(c1) + (1.0-grid % fw(s))*phi_y(c2)
      phiz_f1 = grid % fw(s)*phi_z(c1) + (1.0-grid % fw(s))*phi_z(c2)
      phix_f2 = phix_f1 
      phiy_f2 = phiy_f1 
      phiz_f2 = phiz_f1 
      dif_eff1 =     grid % f(s)  * (diffusivity+vis_t(c1)/sc_t)  &
               + (1.-grid % f(s)) * (diffusivity+vis_t(c2)/sc_t)
      dif_eff2 = dif_eff1 
    else
      phix_f1 = phi_x(c1) 
      phiy_f1 = phi_y(c1) 
      phiz_f1 = phi_z(c1) 
      phix_f2 = phix_f1 
      phiy_f2 = phiy_f1 
      phiz_f2 = phiz_f1 
      dif_eff1 = diffusivity + vis_t(c1) / sc_t   
      dif_eff2 = dif_eff1 
    end if

!   For species, we don't have some wall diffusivity
!   if(turbulence_model .eq. K_EPS .or.  &
!      turbulence_model .eq. K_EPS_ZETA_F) then 
!     if(c2 < 0) then
!       if(Var_Mod_Bnd_Cell_Type(phi,c2) .eq. WALL .or.  &
!          Var_Mod_Bnd_Cell_Type(phi,c2) .eq. WALLFL) then
!         dif_eff1 = con_wall(c1)
!         dif_eff2 = dif_eff1
!       end if
!     end if
!   end if

    ! Total (exact) diffusive flux
    f_ex1 = dif_eff1 * (  phix_f1 * grid % sx(s)  &
                        + phiy_f1 * grid % sy(s)  &
                        + phiz_f1 * grid % sz(s))
    f_ex2 = dif_eff2 * (  phix_f2 * grid % sx(s)  &
                        + phiy_f2 * grid % sy(s)  &
                        + phiz_f2 * grid % sz(s))

    ! Implicit diffusive flux
    f_im1 = dif_eff1 * a % fc(s)          &
          * (  phix_f1 * grid % dx(s)      &
             + phiy_f1 * grid % dy(s)      &
             + phiz_f1 * grid % dz(s) )
    f_im2 = dif_eff2 * a % fc(s)          &
          * (  phix_f2 * grid % dx(s)      &
             + phiy_f2 * grid % dy(s)      &
             + phiz_f2 * grid % dz(s) )

    ! Cross diffusion part
    phi % c(c1) = phi % c(c1) + f_ex1 - f_im1
    if(c2 .gt. 0) then
      phi % c(c2) = phi % c(c2) - f_ex2 + f_im2
    end if

    ! Calculate the coefficients for the sysytem matrix

    a12 = dif_eff1 * a % fc(s)
    a21 = dif_eff2 * a % fc(s)

    a12 = a12  - min(flux(s), 0.0)
    a21 = a21  + max(flux(s), 0.0)

    ! Fill the system matrix
    if(c2 > 0) then
      a % val(a % dia(c1))  = a % val(a % dia(c1)) + a12
      a % val(a % dia(c2))  = a % val(a % dia(c2)) + a21
      a % val(a % pos(1,s)) = a % val(a % pos(1,s)) - a12
      a % val(a % pos(2,s)) = a % val(a % pos(2,s)) - a21
    else if(c2 < 0) then

      ! Outflow is included because of the flux 
      ! corrections which also affects velocities
      if( (Var_Mod_Bnd_Cell_Type(phi,c2) .eq. INFLOW) .or.  &
          (Var_Mod_Bnd_Cell_Type(phi,c2) .eq. WALL)   .or.  &
          (Var_Mod_Bnd_Cell_Type(phi,c2) .eq. CONVECT) ) then    
        a % val(a % dia(c1)) = a % val(a % dia(c1)) + a12
        b(c1)  = b(c1)  + a12 * phi % n(c2)

      ! In case of wallflux 
      else if(Var_Mod_Bnd_Cell_Type(phi,c2) .eq. WALLFL) then
        b(c1) = b(c1) + grid % s(s) * phi % q(c2)
      end if

    end if

  end do  ! through sides

  ! Implicit treatment for cross difusive terms
  do c = 1, grid % n_cells
    if(phi % c(c) >= 0) then
      b(c)  = b(c) + phi % c(c)
    else
      a % val(a % dia(c)) = a % val(a % dia(c))  &
                          - phi % c(c) / (phi % n(c) + MICRO)
    end if
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
  if(turbulence_model .eq. RSM_MANCEAU_HANJALIC .or.  &
     turbulence_model .eq. RSM_HANJALIC_JAKIRLIC) then
    if(turbulence_model_variant .ne. STABILIZED) then
      do c = 1, grid % n_cells
        u1uj_phij(c) = -0.22 * t_scale(c) *         &
                   (  uu % n(c) * phi_x(c)          &
                    + uv % n(c) * phi_y(c)          &
                    + uw % n(c) * phi_z(c))
        u2uj_phij(c) = -0.22 * t_scale(c) *         &
                   (  uv % n(c) * phi_x(c)          &
                    + vv % n(c) * phi_y(c)          &
                    + vw % n(c) * phi_z(c))
        u3uj_phij(c) = -0.22 * t_scale(c) *         &
                   (  uw % n(c) * phi_x(c)          &
                    + vw % n(c) * phi_y(c)          &
                    + ww % n(c) * phi_z(c))
      end do
      call Grad_Mod_Component(grid, u1uj_phij, 1, u1uj_phij_x, .true.)
      call Grad_Mod_Component(grid, u2uj_phij, 2, u2uj_phij_y, .true.)
      call Grad_Mod_Component(grid, u3uj_phij, 3, u3uj_phij_z, .true.)
      do c = 1, grid % n_cells
        b(c) = b(c) - (  u1uj_phij_x(c)  &
                       + u2uj_phij_y(c)  &
                       + u3uj_phij_z(c) ) * grid % vol(c)
      end do

      !------------------------------------------------------------------!
      !   Here we clean up transport equation from the false diffusion   !
      !------------------------------------------------------------------!
      do s = 1, grid % n_faces

        c1 = grid % faces_c(1,s)
        c2 = grid % faces_c(2,s)

!   For species, we don't have a function for turbulent Schmidt number
!       sc_t1 = Turbulent_Prandtl_Number(grid, c1)
!       sc_t2 = Turbulent_Prandtl_Number(grid, c2)
!       sc_t  = grid % fw(s) * sc_t1 + (1.0-grid % fw(s)) * sc_t2

        if(c2 > 0) then
          phix_f1 = grid % fw(s)*phi_x(c1) + (1.0-grid % fw(s))*phi_x(c2)
          phiy_f1 = grid % fw(s)*phi_y(c1) + (1.0-grid % fw(s))*phi_y(c2)
          phiz_f1 = grid % fw(s)*phi_z(c1) + (1.0-grid % fw(s))*phi_z(c2)
          phix_f2 = phix_f1 
          phiy_f2 = phiy_f1 
          phiz_f2 = phiz_f1 
          dif_eff1 =      grid % f(s)  * (vis_t(c1)/sc_t )  &
                  + (1. - grid % f(s)) * (vis_t(c2)/sc_t )
          dif_eff2 = dif_eff1 
        else
          phix_f1 = phi_x(c1)
          phiy_f1 = phi_y(c1)
          phiz_f1 = phi_z(c1)
          phix_f2 = phix_f1
          phiy_f2 = phiy_f1
          phiz_f2 = phiz_f1
          dif_eff1 = vis_t(c1) / sc_t
          dif_eff2 = dif_eff1
        end if

        ! Total (exact) diffusive flux
        f_ex1 = dif_eff1 * (  phix_f1 * grid % sx(s)  &
                            + phiy_f1 * grid % sy(s)  &
                            + phiz_f1 * grid % sz(s))
        f_ex2 = dif_eff2 * (  phix_f2 * grid % sx(s)  &
                            + phiy_f2 * grid % sy(s)  &
                            + phiz_f2 * grid % sz(s))

        ! Implicit diffusive flux
        f_im1 = dif_eff1 * a % fc(s) *         &
                (  phix_f1 * grid % dx(s)      &
                 + phiy_f1 * grid % dy(s)      &
                 + phiz_f1 * grid % dz(s) )
        f_im2 = dif_eff2 * a % fc(s) *         &
                (  phix_f2 * grid % dx(s)      &
                 + phiy_f2 * grid % dy(s)      &
                 + phiz_f2 * grid % dz(s) )

        b(c1) = b(c1) - dif_eff1 * (phi % n(c2) - phi % n(c1)) * a % fc(s)  &
              - f_ex1 + f_im1
        if(c2  > 0) then
          b(c2) = b(c2) + dif_eff1 * (phi % n(c2) - phi % n(c1)) * a % fc(s)  &
                + f_ex2 - f_im2
        end if
      end do
    end if
  end if

  call User_Mod_Source(flow, phi, a, b)

  !---------------------------------!
  !                                 !
  !   Solve the equations for phi   !
  !                                 !
  !---------------------------------!

  ! Under-relax the equations
  call Numerics_Mod_Under_Relax(phi, sol)

  ! Call linear solver to solve them
  call Bicg(sol,            &
            phi % n,        &
            b,              &
            phi % precond,  &
            phi % niter,    &
            exec_iter,      &
            phi % tol,      &
            phi % res)

  read(phi % name(3:4), *) ns  ! reterive the number of scalar
  row = ceiling(ns/6)          ! will be 1 (scal. 1-6), 2 (scal. 6-12), etc.
  col = ns - (row-1)*6         ! will be in range 1 - 6

  call Info_Mod_Iter_Fill_User_At(row, col, phi % name, exec_iter, phi % res)

  call Comm_Mod_Exchange_Real(grid, phi % n)

  end subroutine
