!==============================================================================!
  module Numerics_Mod
!------------------------------------------------------------------------------!
!   Module which embodies subroutines and function typical for numerical       !
!   treatment of dicretized equations.  It should lead to reduction of code    !
!   duplication for routinely used procedures.                                 !
!   terms and diffusion terms.                                                 !
!                                                                              !
!   (It is also the first module which has all "use" statements here, in       !
!    the definition of the module itself.  That's a better practice than to
!    have them spread over included functions.)                                !
!------------------------------------------------------------------------------!
!----------------------------------[Modules]-----------------------------------!
  use Comm_Mod,   only: this_proc, Comm_Mod_End, Comm_Mod_Exchange_Real
  use Grid_Mod,   only: Grid_Type
  use Matrix_Mod, only: Matrix_Type
  use Solver_Mod, only: Solver_Type
  use Var_Mod,    only: Var_Type
!------------------------------------------------------------------------------!
  implicit none
!==============================================================================!

  ! Parameters for advection scheme
  integer, parameter :: UPWIND    = 40009
  integer, parameter :: CENTRAL   = 40013
  integer, parameter :: LUDS      = 40031
  integer, parameter :: QUICK     = 40037
  integer, parameter :: SMART     = 40039
  integer, parameter :: GAMMA     = 40063
  integer, parameter :: MINMOD    = 40087
  integer, parameter :: BLENDED   = 40093
  integer, parameter :: SUPERBEE  = 40099
  integer, parameter :: AVL_SMART = 40111

  ! Time integration parameters
  integer, parameter :: LINEAR    = 40123
  integer, parameter :: PARABOLIC = 40127

  contains

  include 'Numerics_Mod/Advection_Scheme.f90'
  include 'Numerics_Mod/Advection_Scheme_Code.f90'
  include 'Numerics_Mod/Advection_Term.f90'
  include 'Numerics_Mod/Advection_Min_Max.f90'
  include 'Numerics_Mod/Inertial_Term.f90'
  include 'Numerics_Mod/Time_Integration_Scheme_Code.f90'
  include 'Numerics_Mod/Under_Relax.f90'

  end module
