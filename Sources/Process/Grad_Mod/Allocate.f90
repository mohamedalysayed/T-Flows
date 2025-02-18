!==============================================================================!
  subroutine Grad_Mod_Allocate(grid)
!------------------------------------------------------------------------------!
!   Allocates memory for this module.                                          !
!------------------------------------------------------------------------------!
!----------------------------------[Modules]-----------------------------------!
  use Grid_Mod
!------------------------------------------------------------------------------!
  implicit none
!---------------------------------[Arguments]----------------------------------!
  type(Grid_Type) :: grid
!==============================================================================!

  allocate(g(6,grid % n_cells));        g         = 0.
  allocate(bad_cells(grid % n_cells));  bad_cells = .false.

  end subroutine
