const all = ['peronda', 'ketua_peronda', 'ketua_krt', 'super_admin'];
const managers = ['ketua_peronda', 'ketua_krt', 'super_admin'];
const admins = ['ketua_krt', 'super_admin'];
// Contracts inspected in the local cPanel recovery bundle dated 2026-09-08.
// These are request variants, not a claim of complete functional coverage.
export const reads = [
  ['profile', 'auth/get_profile.php', all, 'data', 'object'],
  ['states', 'auth/get_locations.php?level=states', all, 'data', 'array'],
  ['schedule', 'schedules/get_user_schedule.php', ['peronda','ketua_peronda'], 'schedules', 'array'],
  ['active_shift', 'attendance/check_active_shift.php', ['peronda','ketua_peronda'], 'has_active_shift', 'boolean'],
  ['inventory', 'equipment/get_inventory.php', all, 'data', 'array'],
  ['notes', 'incidents/get_incidents.php', all, 'data', 'array'],
  ['incident_feed', 'incidents/fetch_incidents.php?page=1&limit=10', all, 'data', 'array'],
  ['notifications', 'notifications/get_notifications.php', all, 'data.notifications', 'array'],
  ['sos_poll', 'incidents/check_sos.php', managers, 'data', 'array'],
  ['stats', 'admin/get_stats.php', managers, 'data', 'object'],
  ['members', 'auth/get_patrollers.php', managers, 'data', 'array'],
  ['squads', 'admin/squads.php', managers, 'data', 'array'],
  ['admin_schedules', 'admin/schedules.php', admins, 'data', 'array'],
  ['attendance_logs', 'attendance/get_logs.php', managers, 'data', 'array'],
  ['pending_returns', 'attendance/get_pending_returns.php', managers, 'data', 'array'],
  ['equipment_logs', 'equipment/get_logs.php', managers, 'data', 'array'],
  ['assessment', 'attendance/get_squad_attendance_assessment.php', ['ketua_peronda'], 'members', 'array'],
  ['active_shifts', 'admin/get_active_shifts.php', admins, 'data', 'array'],
  ['monthly_report', 'incidents/get_lampiran_6_summary.php?month_offset=0&level=daerah', admins, 'data', 'object', 5000],
  ['overview', 'admin/super_admin_overview.php', ['super_admin'], 'data', 'object'],
  ['locations', 'admin/locations.php?action=list', ['super_admin'], 'data', 'array'],
].map(([id,path,roles,field,shape,limit=2000]) => ({id,path,roles,field,shape,limit,method:'GET'}));

export const writes = [
  ['start_shift','attendance/start_shift.php'],
  ['clock_in','attendance/clock_in.php'],
  ['log_equipment','attendance/log_equipment.php'],
  ['end_shift','attendance/end_shift.php'],
  ['clock_out','attendance/clock_out.php'],
  ['acknowledge_return','attendance/acknowledge_return.php'],
  ['save_assessment','attendance/save_attendance_assessment.php'],
  ['draft_note','incidents/upload_incident.php',5000],
].map(([id,path,limit=2000]) => ({id,path,limit,method:'POST'}));
export const extra = [{id:'return_preview',path:'attendance/get_return_preview.php',limit:2000,method:'GET'}];
export const loginEndpoint = {id:'login',path:'auth/login.php',limit:2000,method:'POST'};
export const catalog = [loginEndpoint, ...reads, ...extra, ...writes];
