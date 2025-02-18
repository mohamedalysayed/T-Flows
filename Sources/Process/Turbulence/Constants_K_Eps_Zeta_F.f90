!==============================================================================!
  subroutine Constants_K_Eps_Zeta_F()
!------------------------------------------------------------------------------!
!   Initializes constants for k-eps-zeta-f and hybrid k-eps-zeta-f             !
!   turbulence models.                                                         ! 
!------------------------------------------------------------------------------!
!----------------------------------[Modules]-----------------------------------!
  use Rans_Mod
  use Control_Mod
!------------------------------------------------------------------------------!
  implicit none
!==============================================================================!

  ! call Control_Mod_Turbulence_Model(.true.)
  ! call Control_Mod_Turbulence_Model_Variant(.true.)

  c_1e         =  1.4
  c_2e         =  1.9
  c_mu         =  0.09
  c_mu_d       =  0.22
  c_mu25       =  sqrt(sqrt(c_mu))
  c_mu75       =  c_mu25**3
  c_mu_theta   =  0.1225  ! c_mu_theta5**2
  c_mu_theta5  =  0.35    ! defined as -theta*u_n/sqrt(theta^2 * kin)
  kappa        =  0.41    ! von Karman constant for momentum 
  kappa_theta  =  0.38    ! von Karman constant for temperature
  e_log        =  8.342
  c_l          =  0.36
  c_t          =  6.0
  c_nu         = 85.0
  alpha        =  0.012
  c_f1         =  1.4
  c_f2         =  0.3

  kin  % sigma = 1.0
  eps  % sigma = 1.3
  zeta % sigma = 1.2
  t2   % sigma = 1.1

  end subroutine
