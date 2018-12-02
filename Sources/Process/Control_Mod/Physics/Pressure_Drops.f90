!==============================================================================!
  subroutine Control_Mod_Pressure_Drops(verbose)
!------------------------------------------------------------------------------!
!----------------------------------[Modules]-----------------------------------!
  use Bulk_Mod,  only: Bulk_Type
  use Field_Mod, only: bulk
!------------------------------------------------------------------------------!
  implicit none
!---------------------------------[Arguments]----------------------------------!
  logical, optional :: verbose
!-----------------------------------[Locals]-----------------------------------!
  real :: def(3)
  real :: val(3)
!==============================================================================!

  data def / 0.0, 0.0, 0.0 /

  call Control_Mod_Read_Real_Array('PRESSURE_DROPS', 3, def,  &
                                    val, verbose)

  bulk % p_drop_x = val(1)
  bulk % p_drop_y = val(2)
  bulk % p_drop_z = val(3)

  end subroutine
