!==============================================================================!
  subroutine Calculate_Vis_T_K_Eps(grid)
!------------------------------------------------------------------------------!
!   Computes the turbulent viscosity for RANS models.                          !
!                                                                              !
!   In the domain:                                                             !
!   For k-eps model :                                                          !
!                                                                              !
!   vis_t = c_mu * rho * k^2 * eps                                             !
!                                                                              !
!   On the boundary (wall viscosity):                                          !
!   vis_tw = y^+ * vis_t kappa / (E * ln(y^+))                                 !
!                                                                              !
!   For k-eps-v2f model :                                                      !
!                                                                              !
!   vis_t = CmuD * rho * Tsc  * vv                                             !
!----------------------------------[Modules]-----------------------------------!
  use Const_Mod
  use Control_Mod
  use Flow_Mod
  use Comm_Mod
  use Les_Mod
  use Rans_Mod
  use Grid_Mod
!  use Work_Mod, only: re_t => r_cell_01,  &
!                      f_mu => r_cell_02
!------------------------------------------------------------------------------!
  implicit none
!---------------------------------[Arguments]----------------------------------!
  type(Grid_Type) :: grid
!-----------------------------------[Locals]-----------------------------------!
  integer :: c1, c2, s, c
  real    :: pr, beta, ebf
  real    :: u_tan, u_nor_sq, u_nor, u_tot_sq, u_tau_new
  real    :: kin_vis 
  real    :: u_plus, y_star, re_t, f_mu
!==============================================================================!
!   Dimensions:                                                                !
!                                                                              !
!   production    p_kin    [m^2/s^3]   | rate-of-strain  shear    [1/s]        !
!   dissipation   eps % n  [m^2/s^3]   | turb. visc.     vis_t    [kg/(m*s)]   !
!   wall shear s. tau_wall [kg/(m*s^2)]| dyn visc.       viscosity[kg/(m*s)]   !
!   density       density  [kg/m^3]    | turb. kin en.   kin % n  [m^2/s^2]    !
!   cell volume   vol      [m^3]       | length          lf       [m]          !
!   left hand s.  A        [kg/s]      | right hand s.   b        [kg*m^2/s^3] !
!   wall visc.    vis_wall [kg/(m*s)]  | kinematic viscosity      [m^2/s]      !
!   thermal cap.  capacity[m^2/(s^2*K)]| therm. conductivity     [kg*m/(s^3*K)]!
!------------------------------------------------------------------------------!
!   p_kin = 2*vis_t / density S_ij S_ij                                        !
!   shear = sqrt(2 S_ij S_ij)                                                  !
!------------------------------------------------------------------------------!

  ! kinematic viscosities
  kin_vis = viscosity/density

  do c = 1, grid % n_cells
    re_t = kin % n(c)*kin % n(c)/(viscosity*eps % n(c))

    y_star = (viscosity * eps % n(c))**0.25 * grid % wall_dist(c)/viscosity

    f_mu = (1.0 - exp(-y_star/14.0))**2.0*(1.0                              &   
          + 5.0*exp(-(re_t/200.0)*(re_t/200.0))/re_t**0.75)

    f_mu = min(1.0,f_mu)

    vis_t(c) = f_mu * c_mu * density * kin % n(c) * kin % n(c) / eps % n(c)
  end do

  do s = 1, grid % n_faces
    c1 = grid % faces_c(1,s)
    c2 = grid % faces_c(2,s)

    if(c2 < 0) then
      if(Grid_Mod_Bnd_Cond_Type(grid,c2) .eq. WALL .or.  &
         Grid_Mod_Bnd_Cond_Type(grid,c2) .eq. WALLFL) then

        u_tot_sq = u % n(c1) * u % n(c1) &
                 + v % n(c1) * v % n(c1) &
                 + w % n(c1) * w % n(c1)
        u_nor  = ( u % n(c1) * grid % sx(s)     &
                 + v % n(c1) * grid % sy(s)     &
                 + w % n(c1) * grid % sz(s) )   &
                 / sqrt(  grid % sx(s)*grid % sx(s)  &
                        + grid % sy(s)*grid % sy(s)  &
                        + grid % sz(s)*grid % sz(s))
        u_nor_sq = u_nor*u_nor

        if( u_tot_sq  > u_nor_sq) then
          u_tan = sqrt(u_tot_sq - u_nor_sq)
        else
          u_tan = TINY
        end if


        u_tau(c1) = c_mu25 * sqrt(kin % n(c1))
        y_plus(c1) = u_tau(c1) * grid % wall_dist(c1) / kin_vis

        tau_wall(c1) = density*kappa*u_tau(c1)*u_tan / &
                       log(e_log*max(y_plus(c1),1.05))

        u_tau_new = sqrt(tau_wall(c1)/density)
        y_plus(c1) = u_tau_new * grid % wall_dist(c1) / kin_vis
        ebf = 0.01 * y_plus(c1)**4.0 / (1.0 + 5.0*y_plus(c1))

        u_plus = log(max(y_plus(c1),1.05)*e_log)/kappa

        if(y_plus(c1) < 3.0) then
          vis_wall(c1) = vis_t(c1) + viscosity
        else
          vis_wall(c1) = y_plus(c1) * viscosity / & 
                        (y_plus(c1) * exp(-1.0*ebf) + & 
                         u_plus * exp(-1.0/ebf) + TINY)
        end if

        if(rough_walls) then
          y_plus(c1) = (grid % wall_dist(c1)+z_o)*u_tau(c1)/kin_vis
          u_plus = log((grid % wall_dist(c1)+z_o))/(kappa + TINY) + TINY
          vis_wall(c1) = y_plus(c1) * viscosity * kappa / & 
                         log((grid % wall_dist(c1)+z_o)/z_o)
        end if

        if(heat_transfer) then
          call Control_Mod_Turbulent_Prandtl_Number(pr_t)
          pr = viscosity * capacity / conductivity
          beta = 9.24 * ((pr/pr_t)**0.75 - 1.0) * & 
            (1.0 + 0.28 * exp(-0.007*pr/pr_t))
          ebf = 0.01 * (pr*y_plus(c1))**4 / & 
            ((1.0 + 5.0 * pr**3 * y_plus(c1)) + TINY)
          con_wall(c1) = y_plus(c1)*viscosity*capacity/(y_plus(c1)*pr* &
            exp(-1.0 * ebf) + (u_plus + beta)*pr_t*exp(-1.0/ebf) + TINY)
        end if
      end if  ! Grid_Mod_Bnd_Cond_Type(grid,c2).eq.WALL or WALLFL
    end if    ! c2 < 0
  end do

  call Comm_Mod_Exchange_Real(grid, vis_t)
  call Comm_Mod_Exchange_Real(grid, vis_wall)

  end subroutine
