!==============================================================================!
  real function Roughness_Coefficient(grid, c)
!------------------------------------------------------------------------------!
!   Set lower limit to roughness coefficient based on wall distance. 
!------------------------------------------------------------------------------!
!----------------------------------[Modules]-----------------------------------!
  use Const_Mod,      only: TINY
  use Grid_Mod,       only: Grid_Type
  use Rans_Mod,       only: z_o
!------------------------------------------------------------------------------!
  implicit none
!---------------------------------[Arguments]----------------------------------!
  type(Grid_Type) :: grid
  integer         :: c
!==============================================================================!

  Roughness_Coefficient = z_o  

  end function