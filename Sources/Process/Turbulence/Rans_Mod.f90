!==============================================================================!
  module Rans_Mod
!------------------------------------------------------------------------------!
!   Definition of variables used by RANS turbulence models.                    !
!------------------------------------------------------------------------------!
!----------------------------------[Modules]-----------------------------------!
  use Var_Mod
  use Turbulence_Mod
!------------------------------------------------------------------------------!
  implicit none
!==============================================================================!

  ! Turbulence models variables
  type(Var_Type), target :: kin
  type(Var_Type), target :: eps
  type(Var_Type), target :: zeta
  type(Var_Type), target :: f22
  type(Var_Type), target :: vis
  type(Var_Type), target :: t2

  ! Constants for the k-eps model:
  real :: c_1e, c_2e, c_3e, c_mu, c_mu25, c_mu75, kappa, e_log

  ! Constants for the k-eps-v2f model:
  real :: c_mu_d, c_l, c_t, alpha, c_nu, c_f1, c_f2
  real :: g1, g1_star, g2, g3, g3_star, g4, g5, c_theta

  ! Constants for the energy model:
  real :: c_mu_theta, c_mu_theta5, kappa_theta

  ! Constants for the Spalart-Allmaras model:
  real :: c_b1, c_b2, c_w1, c_w2, c_w3, c_v1

  ! Effective turbulent viscosity
  real, allocatable :: vis_t_eff(:)
  real, allocatable :: vis_t_sgs(:)

  ! Lenght and Time Scales
  real,allocatable :: l_scale(:)
  real,allocatable :: t_scale(:)

  ! Production of turbulent kinetic energy
  real,allocatable :: p_kin(:), p_t2(:)

  ! Hydraulic roughness (constant and variable)
  real              :: z_o 
  real, allocatable :: z_o_f(:)

  ! Buoyancy production for k-eps-zeta-f model
  ! (bouy_beta is only set to 1 and used as such.  Is it needed?)
  real,allocatable :: g_buoy(:)
  real,allocatable :: buoy_beta(:)
  real,allocatable :: g_kin(:)
 
  end module 
