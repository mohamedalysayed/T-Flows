!==============================================================================!
  subroutine Backup_Mod_Save(fld, time_step, time_step_stat, name_save)
!------------------------------------------------------------------------------!
!   Saves backup files name.backup                                             !
!------------------------------------------------------------------------------!
!----------------------------------[Modules]-----------------------------------!
  use Const_Mod
  use Comm_Mod
  use Rans_Mod
  use Name_Mod,  only: problem_name
  use Field_Mod, only: Field_Type, heat_transfer
  use Grid_Mod,  only: Grid_Type
  use Bulk_Mod,  only: Bulk_Type
!------------------------------------------------------------------------------!
  implicit none
!---------------------------------[Arguments]----------------------------------!
  type(Field_Type), target :: fld
  integer                  :: time_step       ! current time step
  integer                  :: time_step_stat  ! starting step for statistics
  character(len=*)         :: name_save
!-----------------------------------[Locals]-----------------------------------!
  type(Grid_Type), pointer :: grid
  type(Bulk_Type), pointer :: bulk
  type(Var_Type),  pointer :: phi
  character(len=80)        :: name_out, store_name, name_mean
  integer                  :: fh, d, vc, sc
!==============================================================================!

  ! Take aliases
  grid => fld % pnt_grid
  bulk => fld % bulk

  store_name = problem_name

  problem_name = name_save

  ! Name backup file
  call Name_File(0, name_out, '.backup')

  ! Open backup file
  call Comm_Mod_Open_File_Write(fh, name_out)

  ! Create new types
  call Comm_Mod_Create_New_Types(grid)

  ! Initialize displacement
  d = 0

  ! Intialize number of stored variables
  vc = 0

  !-----------------------------------------------------------------------!
  !   Save cell-centre coordinates.  Could be useful for interpolations   !
  !-----------------------------------------------------------------------!
  call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'x_coords', grid % xc(-nb_s:nc_s))
  call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'y_coords', grid % yc(-nb_s:nc_s))
  call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'z_coords', grid % zc(-nb_s:nc_s))

  !---------------!
  !               !
  !   Save data   !
  !               !
  !---------------!

  ! Time step
  call Backup_Mod_Write_Int(fh, d, vc, 'time_step', time_step)

  ! Number of processors
  call Backup_Mod_Write_Int(fh, d, vc, 'n_proc', n_proc)

  ! Bulk flows and pressure drops in each direction
  call Backup_Mod_Write_Real(fh, d, vc, 'bulk_flux_x',   bulk % flux_x)
  call Backup_Mod_Write_Real(fh, d, vc, 'bulk_flux_y',   bulk % flux_y)
  call Backup_Mod_Write_Real(fh, d, vc, 'bulk_flux_z',   bulk % flux_z)
  call Backup_Mod_Write_Real(fh, d, vc, 'bulk_flux_x_o', bulk % flux_x_o)
  call Backup_Mod_Write_Real(fh, d, vc, 'bulk_flux_y_o', bulk % flux_y_o)
  call Backup_Mod_Write_Real(fh, d, vc, 'bulk_flux_z_o', bulk % flux_z_o)
  call Backup_Mod_Write_Real(fh, d, vc, 'bulk_p_drop_x', bulk % p_drop_x)
  call Backup_Mod_Write_Real(fh, d, vc, 'bulk_p_drop_y', bulk % p_drop_y)
  call Backup_Mod_Write_Real(fh, d, vc, 'bulk_p_drop_z', bulk % p_drop_z)

  !----------------------------!
  !                            !
  !   Navier-Stokes equation   !
  !                            !
  !----------------------------!

  !--------------!
  !   Velocity   !
  !--------------!
  call Backup_Mod_Write_Variable(fh, d, vc, 'u_velocity', fld % u)
  call Backup_Mod_Write_Variable(fh, d, vc, 'v_velocity', fld % v)
  call Backup_Mod_Write_Variable(fh, d, vc, 'w_velocity', fld % w)

  !--------------------------------------!
  !   Pressure and pressure correction   !
  !--------------------------------------!
  call Backup_Mod_Write_Cell_Bnd(fh,d,vc, 'press',     fld %  p % n(-nb_s:nc_s))
  call Backup_Mod_Write_Cell_Bnd(fh,d,vc, 'press_corr',fld % pp % n(-nb_s:nc_s))

  !----------------------!
  !   Mass flow raters   !
  !----------------------!
  call Backup_Mod_Write_Face(fh, d, vc, grid, fld % flux)

  !--------------!
  !              !
  !   Etnhalpy   !
  !              !
  !--------------!
  if(heat_transfer) then
    call Backup_Mod_Write_Variable(fh, d, vc, 'temp', fld % t)
  end if

  !-----------------------!
  !                       !
  !   Turbulence models   !
  !                       !
  !-----------------------!

  !-----------------!
  !   K-eps model   !
  !-----------------!
  if(turbulence_model .eq. K_EPS) then

    ! K and epsilon
    call Backup_Mod_Write_Variable(fh, d, vc, 'kin', kin)
    call Backup_Mod_Write_Variable(fh, d, vc, 'eps', eps)

    ! Other turbulent quantities
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'p_kin',    p_kin   (-nb_s:nc_s))
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'u_tau',    u_tau   (-nb_s:nc_s))
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'y_plus',   y_plus  (-nb_s:nc_s))
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'vis_t',    vis_t   (-nb_s:nc_s))
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'vis_wall', vis_wall(-nb_s:nc_s))
    call Backup_Mod_Write_Cell    (fh, d, vc, 'tau_wall', tau_wall  (1:nc_s))

    ! Turbulence quantities connected with heat transfer
    if(heat_transfer) then
      call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'con_wall',con_wall(-nb_s:nc_s))
    end if
  end if

  !------------------------!
  !   K-eps-zeta-f model   !
  !------------------------!
  if(turbulence_model .eq. K_EPS_ZETA_F .or.  &
     turbulence_model .eq. HYBRID_LES_RANS) then

    ! K, eps, zeta and f22
    call Backup_Mod_Write_Variable(fh, d, vc, 'kin',  kin)
    call Backup_Mod_Write_Variable(fh, d, vc, 'eps',  eps)
    call Backup_Mod_Write_Variable(fh, d, vc, 'zeta', zeta)
    call Backup_Mod_Write_Variable(fh, d, vc, 'f22',  f22)

    ! Other turbulent quantities
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'p_kin',    p_kin   (-nb_s:nc_s))
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'u_tau',    u_tau   (-nb_s:nc_s))
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'y_plus',   y_plus  (-nb_s:nc_s))
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'vis_t',    vis_t   (-nb_s:nc_s))
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'vis_wall', vis_wall(-nb_s:nc_s))
    call Backup_Mod_Write_Cell    (fh, d, vc, 'tau_wall', tau_wall  (1:nc_s))
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 't_scale',  t_scale(-nb_s:nc_s))
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'l_scale',  l_scale(-nb_s:nc_s))
  end if

  if( (turbulence_model .eq. K_EPS_ZETA_F .and. heat_transfer) .or. &
      (turbulence_model .eq. HYBRID_LES_RANS .and. heat_transfer) ) then
    call Backup_Mod_Write_Variable(fh, d, vc, 't2',       t2)
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'p_t2',     p_t2    (-nb_s:nc_s))
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'con_wall', con_wall(-nb_s:nc_s))
    if(turbulence_statistics .and.  &
       time_step > time_step_stat) then
      call Backup_Mod_Write_Variable_Mean(fh, d, vc, 't2_mean', t2)
    end if
  end if


  !----------------------------!
  !   Reynolds stress models   !
  !----------------------------!
  if(turbulence_model .eq. RSM_MANCEAU_HANJALIC .or.  &
     turbulence_model .eq. RSM_HANJALIC_JAKIRLIC) then

    ! Reynolds stresses
    call Backup_Mod_Write_Variable(fh, d, vc, 'uu',  uu)
    call Backup_Mod_Write_Variable(fh, d, vc, 'vv',  vv)
    call Backup_Mod_Write_Variable(fh, d, vc, 'ww',  ww)
    call Backup_Mod_Write_Variable(fh, d, vc, 'uv',  uv)
    call Backup_Mod_Write_Variable(fh, d, vc, 'uw',  uw)
    call Backup_Mod_Write_Variable(fh, d, vc, 'vw',  vw)

    ! Epsilon
    call Backup_Mod_Write_Variable(fh, d, vc, 'eps', eps)

    ! F22
    if(turbulence_model .eq. RSM_MANCEAU_HANJALIC) then
      call Backup_Mod_Write_Variable(fh, d, vc, 'f22',  f22)
    end if

    ! Other turbulent quantities 
    call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'vis_t', vis_t(-nb_s:nc_s))

    ! Turbulence quantities connected with heat transfer
    if(heat_transfer) then
      call Backup_Mod_Write_Cell_Bnd(fh, d, vc, 'con_wall',con_wall(-nb_s:nc_s))
    end if
  end if

  !------------------!
  !   Save scalars   !
  !------------------!
  do sc = 1, fld % n_scalars
    phi => fld % scalar(sc)
    call Backup_Mod_Write_Variable(fh, d, vc, phi % name, phi)
  end do

  !-----------------------------------------!
  !                                         !
  !   Turbulent statistics for all models   !
  !                                         !
  !-----------------------------------------!
  if(turbulence_statistics .and.  &
     time_step > time_step_stat) then

    call Backup_Mod_Write_Variable_Mean(fh, d, vc, 'u_mean', fld % u)
    call Backup_Mod_Write_Variable_Mean(fh, d, vc, 'v_mean', fld % v)
    call Backup_Mod_Write_Variable_Mean(fh, d, vc, 'w_mean', fld % w)

    call Backup_Mod_Write_Variable_Mean(fh, d, vc, 'uu_mean', uu)
    call Backup_Mod_Write_Variable_Mean(fh, d, vc, 'vv_mean', vv)
    call Backup_Mod_Write_Variable_Mean(fh, d, vc, 'ww_mean', ww)
    call Backup_Mod_Write_Variable_Mean(fh, d, vc, 'uv_mean', uv)
    call Backup_Mod_Write_Variable_Mean(fh, d, vc, 'uw_mean', uw)
    call Backup_Mod_Write_Variable_Mean(fh, d, vc, 'vw_mean', vw)

    if(heat_transfer) then
      call Backup_Mod_Write_Variable_Mean(fh, d, vc, 't_mean',  fld % t)
      call Backup_Mod_Write_Variable_Mean(fh, d, vc, 'tt_mean', tt)
      call Backup_Mod_Write_Variable_Mean(fh, d, vc, 'ut_mean', ut)
      call Backup_Mod_Write_Variable_Mean(fh, d, vc, 'vt_mean', vt)
      call Backup_Mod_Write_Variable_Mean(fh, d, vc, 'wt_mean', wt)
    end if

    do sc = 1, fld % n_scalars
      phi => fld % scalar(sc)
      name_mean = phi % name
      name_mean(5:9) = '_mean'
      call Backup_Mod_Write_Variable_Mean(fh, d, vc, name_mean, phi)
    end do
  end if

  ! Variable count (store +1 to count its own self)
  call Backup_Mod_Write_Int(fh, d, vc, 'variable_count', vc + 1)

  if(this_proc < 2) then
    print *, '# Wrote ', vc, ' variables!'
  end if

  ! Close backup file
  call Comm_Mod_Close_File(fh)

  problem_name = store_name

  end subroutine
