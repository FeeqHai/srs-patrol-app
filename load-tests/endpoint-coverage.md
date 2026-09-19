# Endpoint coverage inventory

Source: local cPanel recovery bundle dated 2026-09-08. This is a preparation inventory, not executed results. Live deployment equivalence is not established.

47 endpoint PHP files found, excluding config helpers. 21 endpoint files have a read-suite variant. Login and eight controlled write endpoints are separate. Multiple methods/actions and filter combinations within one PHP file need separate cases.

| Endpoint | Prepared coverage | Limits / prerequisites |
|---|---|---|
| `admin/get_active_shifts.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `admin/get_stats.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `admin/locations.php` | Read suite (GET) | Default query/list variant and mapped roles only. POST create/update/delete actions are NOT tested. |
| `admin/schedules.php` | Read suite (GET) | Default query/list variant and mapped roles only. POST create/update/delete actions are NOT tested. |
| `admin/squads.php` | Read suite (GET) | Default query/list variant and mapped roles only. POST create/update/delete actions are NOT tested. |
| `admin/super_admin_overview.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `admin/update_user.php` | NOT AUTOMATED | Requires its own prepared write/deletion/status-change case. |
| `attendance/acknowledge_return.php` | Controlled write flow (opt-in) | One sequential prepared-data case; NOT concurrent write load. |
| `attendance/check_active_shift.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `attendance/clock_in.php` | Controlled write flow (opt-in) | One sequential prepared-data case; NOT concurrent write load. |
| `attendance/clock_out.php` | Controlled write flow (opt-in) | One sequential prepared-data case; NOT concurrent write load. |
| `attendance/end_shift.php` | Controlled write flow (opt-in) | One sequential prepared-data case; NOT concurrent write load. |
| `attendance/get_logs.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `attendance/get_pending_returns.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `attendance/get_return_preview.php` | Controlled write flow (GET verification) | Requires active attendance and issued test equipment. |
| `attendance/get_squad_attendance_assessment.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `attendance/log_equipment.php` | Controlled write flow (opt-in) | One sequential prepared-data case; NOT concurrent write load. |
| `attendance/save_attendance_assessment.php` | Controlled write flow (opt-in) | One sequential prepared-data case; NOT concurrent write load. |
| `attendance/start_shift.php` | Controlled write flow (opt-in) | One sequential prepared-data case; NOT concurrent write load. |
| `auth/change_password.php` | NOT AUTOMATED | Requires disposable credentials and account recovery plan. |
| `auth/get_locations.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `auth/get_patrollers.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `auth/get_profile.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `auth/login.php` | Smoke setup + separate login load | Valid login only; password changes and logout are separate. |
| `auth/register.php` | NOT AUTOMATED | Requires prepared identity/consent/verification session data; OCR needs device testing. |
| `auth/remove_profile_photo.php` | NOT AUTOMATED | Requires test image and restoration plan; no image-upload load claim. |
| `auth/update_profile_photo.php` | NOT AUTOMATED | Requires test image and restoration plan; no image-upload load claim. |
| `auth/upload_profile_image.php` | NOT AUTOMATED | Requires test image and restoration plan; no image-upload load claim. |
| `auth/verification/complete.php` | NOT AUTOMATED | Requires prepared identity/consent/verification session data; OCR needs device testing. |
| `auth/verification/start.php` | NOT AUTOMATED | Requires prepared identity/consent/verification session data; OCR needs device testing. |
| `equipment/get_inventory.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `equipment/get_logs.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `equipment/manage_equipment.php` | NOT AUTOMATED | Requires its own prepared write/deletion/status-change case. |
| `incidents/acknowledge_sos.php` | NOT AUTOMATED | Needs an isolated emergency scenario and receipt/acknowledgement evidence. |
| `incidents/check_sos.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `incidents/delete_incident.php` | NOT AUTOMATED | Requires its own prepared write/deletion/status-change case. |
| `incidents/fetch_incidents.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `incidents/get_incidents.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `incidents/get_lampiran_6_summary.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `incidents/update_status.php` | NOT AUTOMATED | Requires its own prepared write/deletion/status-change case. |
| `incidents/upload_incident.php` | Controlled write flow (opt-in) | One sequential prepared-data case; NOT concurrent write load. |
| `notifications/clear_history.php` | NOT AUTOMATED | Requires disposable notification records; do not clear real history. |
| `notifications/delete_notification.php` | NOT AUTOMATED | Requires disposable notification records; do not clear real history. |
| `notifications/get_notifications.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `notifications/mark_read.php` | NOT AUTOMATED | Requires disposable notification records; do not clear real history. |
| `schedules/get_user_schedule.php` | Read suite (GET) | Default query/list variant and mapped roles only. |
| `tracking/sos_alert.php` | NOT AUTOMATED | Needs an isolated emergency scenario and receipt/acknowledgement evidence. |

App-only settings, logout state, camera QR scanning, OCR, local PDF construction, mobile rendering and permissions require device testing. API timing cannot establish their performance. No endpoint is classified as passed until its recorded run demonstrates that result.
