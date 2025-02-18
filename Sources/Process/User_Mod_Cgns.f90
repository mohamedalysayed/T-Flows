!==============================================================================!
  module User_Mod
!------------------------------------------------------------------------------!
!   This is embrio of a future User module, a place where user can
!   define his/her variables and pass them around his functions
!------------------------------------------------------------------------------!
  use Grid_Mod
  use Var_Mod
!------------------------------------------------------------------------------!
  implicit none

  integer           :: n_user_arrays
  real, allocatable :: user_array(:,:)

  contains

  include 'User_Mod/Allocate.f90'
  include 'User_Mod/Before_Exit.f90'
  include 'User_Mod/Beginning_Of_Time_Step.f90'
  include 'User_Mod/Beginning_Of_Compute_Energy.f90'
  include 'User_Mod/Beginning_Of_Compute_Momentum.f90'
  include 'User_Mod/Beginning_Of_Compute_Pressure.f90'
  include 'User_Mod/Beginning_Of_Correct_Velocity.f90'
  include 'User_Mod/Calculate_Mean.f90'
  include 'User_Mod/End_Of_Compute_Energy.f90'
  include 'User_Mod/End_Of_Compute_Momentum.f90'
  include 'User_Mod/End_Of_Compute_Pressure.f90'
  include 'User_Mod/End_Of_Correct_Velocity.f90'
  include 'User_Mod/End_Of_Time_Step.f90'
  include 'User_Mod/Initialize.f90'
  include 'User_Mod/Force.f90'
  include 'User_Mod/Save_Results.f90'
  include 'User_Mod/Save_Cgns_Results.f90'
  include 'User_Mod/Source.f90'

  end module 


