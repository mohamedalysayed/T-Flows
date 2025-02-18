!==============================================================================!
  subroutine Backup_Mod_Read_Face(fh, disp, vc, grid, flux)
!------------------------------------------------------------------------------!
!   Reads face-based variable (flux) using cell-based arrays.                  !
!------------------------------------------------------------------------------!
!----------------------------------[Modules]-----------------------------------!
  use Grid_Mod
  use Comm_Mod
  use Work_Mod, only: cells_nf => i_cell_01,  &  ! cells' number of faces
                      ivalues  => i_cell_02,  &  ! work array for int. values
                      rvalues  => r_cell_01      ! work array for real values
!------------------------------------------------------------------------------!
  implicit none
!---------------------------------[Arguments]----------------------------------!
  integer         :: fh, disp, vc
  type(Grid_Type) :: grid
  real            :: flux(grid % n_faces)
!-----------------------------------[Locals]-----------------------------------!
  integer              :: s, c, c1, c2, cg1, cg2, mc, max_cnt
  integer, allocatable :: cells_cg(:,:)   ! cells' cells
  integer, allocatable :: cells_fc(:,:)   ! cells' faces
  character(len=12)    :: cf_name = 'cell_flux_00'
!==============================================================================!

  allocate(cells_cg (24, grid % n_cells));  cells_cg  = 0
  allocate(cells_fc (24, grid % n_cells));  cells_fc  = 0

  cells_nf(:) = 0

  !---------------------------------------! 
  !   Browse through all faces to form:   !
  !   cells_nf, cells_cg and cells_fc.    !
  !---------------------------------------! 
  do s = 1, grid % n_faces
    c1 = grid % faces_c(1, s)
    c2 = grid % faces_c(2, s)

    ! Take cells' global numbers.  (These are less then zero in 
    ! real boundary cells, but greater than zero in buffer cells.)
    cg1 = grid % comm % cell_glo(c1)
    cg2 = grid % comm % cell_glo(c2)

    ! Store flux to "c1" no matter what
    cells_nf(c1) = cells_nf(c1) + 1
    cells_cg(cells_nf(c1), c1) = cg2
    cells_fc(cells_nf(c1), c1) = s   ! store face number

    ! Store flux to "c2" only if it is a non-boundary cell (real boundary)
    if(c2 > 0 .and. c2 <= grid % n_cells - grid % comm % n_buff_cells) then
      cells_nf(c2) = cells_nf(c2) + 1
      cells_cg(cells_nf(c2), c2) = cg1
      cells_fc(cells_nf(c2), c2) = s   ! store face number
    end if
  end do

  !------------------------------------!
  !    Find maximum number of faces    !
  !   around cell in the entire grid   !
  !------------------------------------!
  max_cnt = 0
  do c = 1, grid % n_cells
    if( cells_nf(c) > max_cnt ) max_cnt = cells_nf(c)
  end do
  call Comm_Mod_Global_Max_Int(max_cnt)

  !-------------------------------------------------!
  !   Update neighbour information in the buffers   !
  !-------------------------------------------------!

  ! Gather information on all neighbours in buffers, one by one
  do mc = 1, max_cnt

    ! Exchange neighbour information at level "mc"
    do c = 1, grid % n_cells
      ivalues(c) = cells_cg(mc,c)
    end do
    call Comm_Mod_Exchange_Int(grid, ivalues)

    ! Update buffer cells with neighbors
    do c = grid % n_cells - grid % comm % n_buff_cells + 1, grid % n_cells
      cells_nf(c) = cells_nf(c) + 1
      cells_cg(cells_nf(c), c) = ivalues(c) 
    end do
  end do

  !--------------------------------------!
  !     Sort fluxes for each cell by     !
  !   global numbers of its neighbours   !
  !--------------------------------------!
  do c = 1, grid % n_cells
    call Sort_Mod_Int_Carry_Int(cells_cg(1:cells_nf(c), c),  &
                                cells_fc(1:cells_nf(c), c))
  end do

  !---------------------------------------------!
  !   Read cell-based fluxes from backup file   !
  !                                             !
  !   Keep in mind that here each cell has      !
  !   fluxes defined at all of the faces        !
  !   surrounding it.                           !
  !---------------------------------------------!
  do mc = 1, max_cnt
    rvalues(:) = 0.0
    write(cf_name(11:12), '(i2.2)') mc  ! set name of the backup variable
    call Backup_Mod_Read_Cell(fh, disp, vc, cf_name, rvalues(1:nc_s))
    call Comm_Mod_Exchange_Real(grid, rvalues)
    do c = 1, grid % n_cells - grid % comm % n_buff_cells
      if( cells_cg(mc, c) .ne. 0 ) then
        flux( cells_fc(mc, c) ) = rvalues(c)
      end if
    end do
  end do

  !--------------------------------------------!
  !        Correct the signs of fluxes         !
  !   (Remember, they are defined to be pos-   !
  !    itive from cg1 to cg2; and cg2 > cg1)   !
  !--------------------------------------------!
  do s = 1, grid % n_faces
    c1  = grid % faces_c(1,s)
    c2  = grid % faces_c(2,s)
    cg1 = grid % comm % cell_glo(c1)
    cg2 = grid % comm % cell_glo(c2)
    if(cg2 > 0 .and. cg2 < cg1) then
      flux(s) = -flux(s)
    end if
  end do

  deallocate(cells_cg)
  deallocate(cells_fc)

  end subroutine
