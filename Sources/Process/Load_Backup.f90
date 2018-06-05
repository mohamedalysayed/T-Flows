!==============================================================================!
  subroutine Load_Backup(grid, time_step, restart)
!------------------------------------------------------------------------------!
!   Read backup files. name.backup                                             !
!----------------------------------[Modules]-----------------------------------!
  use Const_Mod
  use Flow_Mod
! use Les_Mod
  use Comm_Mod
  use Rans_Mod
  use Grid_Mod
  use Grad_Mod
  use Control_Mod
!------------------------------------------------------------------------------!
  implicit none
!---------------------------------[Arguments]----------------------------------!
  type(Grid_Type) :: grid
  integer         :: time_step
  logical         :: restart 
!-----------------------------------[Locals]-----------------------------------!
  character(len=80) :: name_in, answer
  integer           :: fh, d
!==============================================================================!

  ! Full name is specified in control file
  call Control_Mod_Load_Backup_Name(name_in)

  answer = name_in
  call To_Upper_Case(answer)
  if(answer == 'SKIP') then
    restart = .false.
    return 
  end if

  ! Open backup file
  call Comm_Mod_Open_File_Read(fh, name_in)

  ! Create new types
  call Comm_Mod_Create_New_Types()

  ! Initialize displacement
  d = 0

  !-----------------------------------------------!
  !   Skip three coordinates for the time being   !
  !-----------------------------------------------! 
  ! call Read_Backup_3_Cell_Bnd(fh, d, 'coordinates',   &
  !                             grid % xc(-nb_s:nc_s),  &
  !                             grid % yc(-nb_s:nc_s),  &
  !                             grid % zc(-nb_s:nc_s))

  !---------------!
  !               !
  !   Load data   !
  !               !
  !---------------! 

  ! Time step
  call Read_Backup_Int(fh, d, 'time_step', time_step)

  ! Bulk flows and pressure drops in each direction
  call Read_Backup_Real(fh, d, 'bulk_flux_x',   bulk(1) % flux_x)
  call Read_Backup_Real(fh, d, 'bulk_flux_y',   bulk(1) % flux_y)
  call Read_Backup_Real(fh, d, 'bulk_flux_z',   bulk(1) % flux_z)
  call Read_Backup_Real(fh, d, 'bulk_p_drop_x', bulk(1) % p_drop_x)
  call Read_Backup_Real(fh, d, 'bulk_p_drop_y', bulk(1) % p_drop_y)
  call Read_Backup_Real(fh, d, 'bulk_p_drop_z', bulk(1) % p_drop_z)

  !--------------!
  !   Velocity   !
  !--------------!
  call Read_Backup_Variable(fh, d, 'u_velocity', u)
  call Read_Backup_Variable(fh, d, 'v_velocity', v)
  call Read_Backup_Variable(fh, d, 'w_velocity', w)

  !--------------------------------------!
  !   Pressure and pressure correction   !
  !--------------------------------------!
  call Read_Backup_Cell_Bnd(fh, d, 'press',       p  % n(-nb_s:nc_s))
  call Read_Backup_Cell_Bnd(fh, d, 'press_corr',  pp % n(-nb_s:nc_s))

  !----------------------------------------------------!
  !   Mass flow rates (ask Egor if name is correct?)   !
  !----------------------------------------------------!
  call Read_Backup_Face(fh, d, 'mass_flow_rate', flux(1:nf_s+nbf_s))
  call Calculate_Mass_Flow_Rate(grid)

  !--------------!
  !   Etnhalpy   !
  !--------------!
  if(heat_transfer == YES) then
    call Read_Backup_Variable(fh, d, 'temp', t)
  end if

  !-----------------------!
  !   Turbulence models   !
  !-----------------------!
  if(turbulence_model == K_EPS .or.  &
     turbulence_model == K_EPS_ZETA_F) then

    ! K and epsilon
    call Read_Backup_Variable(fh, d, 'kin', kin)
    call Read_Backup_Variable(fh, d, 'eps', eps)

    ! Other turbulent quantities
    call Read_Backup_Cell_Bnd(fh, d, 'p_kin',    p_kin   (-nb_s:nc_s))
    call Read_Backup_Cell_Bnd(fh, d, 'u_tau',    u_tau   (-nb_s:nc_s))
    call Read_Backup_Cell_Bnd(fh, d, 'y_plus',   y_plus  (-nb_s:nc_s))
    call Read_Backup_Cell_Bnd(fh, d, 'vis_wall', vis_wall(-nb_s:nc_s))
    call Read_Backup_Cell    (fh, d, 'tau_wall', tau_wall  (1:nc_s)  )
  end if

  if(turbulence_model == K_EPS_ZETA_F) then

    ! Zeta and f22
    call Read_Backup_Variable(fh, d, 'zeta', zeta)
    call Read_Backup_Variable(fh, d, 'f22',  f22)

    ! Other turbulent quantities
    call Read_Backup_Cell_Bnd(fh, d, 't_scale',  t_scale(-nb_s:nc_s))
    call Read_Backup_Cell_Bnd(fh, d, 'l_scale',  l_scale(-nb_s:nc_s))
  end if 

  if(turbulence_model .eq. REYNOLDS_STRESS .or.  &                          
     turbulence_model .eq. HANJALIC_JAKIRLIC) then                          

    ! Reynolds stresses
    call Read_Backup_Variable(fh, d, 'uu',  uu)
    call Read_Backup_Variable(fh, d, 'vv',  vv)
    call Read_Backup_Variable(fh, d, 'ww',  ww)
    call Read_Backup_Variable(fh, d, 'uv',  uv)
    call Read_Backup_Variable(fh, d, 'uw',  uw)
    call Read_Backup_Variable(fh, d, 'vw',  vw)

    ! Epsilon
    call Read_Backup_Variable(fh, d, 'eps', eps)

    ! F22
    if(turbulence_model .eq. HANJALIC_JAKIRLIC) then
      call Read_Backup_Variable(fh, d, 'f22',  f22)
    end if

    ! Other turbulent quantities ?
  end if 

  ! Close backup file
  call Comm_Mod_Close_File(fh)

  end subroutine

