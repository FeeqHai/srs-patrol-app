import { check, fail } from 'k6';
import { reads, writes, extra, loginEndpoint } from './catalog.js';
import { loginAll, request, requireOK, thresholds, report, flowCompleted } from './common.js';
const fixture = JSON.parse(open('./patrol-fixture.local.json'));
const endpoints = [loginEndpoint,...reads,...extra,...writes];
const byId = Object.fromEntries(endpoints.map(e=>[e.id,e]));
export const options = {vus:1,iterations:1,setupTimeout:'2m',thresholds:thresholds(writes,false)};
function uuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g,c=> {
    const r=Math.floor(Math.random()*16); return (c==='x'?r:(r&3)|8).toString(16);
  });
}
function call(id,actor,body,validate) {
  return requireOK(request(byId[id],actor,body,byId[id].method==='POST' && id!=='draft_note',validate),id);
}
function guard(ok, label) { if (!check(ok,{[label]:v=>Boolean(v)})) fail(label); }
export function setup() {
  if (fixture.testRecordsOnly !== true || !Number.isFinite(fixture.latitude) || !Number.isFinite(fixture.longitude)
      || !fixture.latitude || !fixture.longitude || Math.abs(fixture.latitude)>90 || Math.abs(fixture.longitude)>180
      || !fixture.squadId || !fixture.scheduleId || JSON.stringify(fixture).includes('REPLACE_')) {
    fail('Complete patrol-fixture.local.json with prepared test records and coordinates before running.');
  }
  if (!Array.isArray(fixture.equipmentIds) || !fixture.equipmentIds.length || new Set(fixture.equipmentIds).size !== fixture.equipmentIds.length) {
    fail('Provide at least one distinct test equipment ID to verify actual equipment issue/return.');
  }
  if (!fixture.noteCategory || fixture.noteCategory === 'Kecemasan') fail('Choose a supported non-emergency note category.');
  const actors=loginAll();
  const leader=actors.find(a=>a.label===fixture.leaderLabel && a.role==='ketua_peronda');
  const member=actors.find(a=>a.label===fixture.patrollerLabel && a.role==='peronda');
  if (!leader || !member) fail('Fixture requires a Patrol Leader and SRS Patroller.');
  for (const actor of [leader,member]) {
    const schedule=call('schedule',actor);
    guard(schedule.squad?.squad_id===fixture.squadId,'Account belongs to the specified test squad');
    guard(schedule.schedules.some(s=>s.id===fixture.scheduleId),'Test schedule is visible');
    const today = new Date(Date.now()+8*60*60*1000).toISOString().slice(0,10);
    const todays = schedule.schedules.filter(s=>s.shift_date===today).sort((a,b)=>a.start_time.localeCompare(b.start_time));
    guard(todays.length===1 && todays[0].id===fixture.scheduleId,'Exactly one prepared schedule exists for today (Malaysia time)');
    guard(call('active_shift',actor).has_active_shift===false,'No pre-existing active attendance');
  }
  const oldLogs=call('attendance_logs',leader).data;
  guard(!oldLogs.some(r=>r.schedule_id===fixture.scheduleId),'Use a fresh schedule without prior attendance');
  const assessment=call('assessment',leader);
  if (assessment.schedule?.id===fixture.scheduleId) {
    guard(!assessment.members.some(m=>m.assessment_status),'No existing assessment will be overwritten');
  }
  const inventory=call('inventory',member).data;
  guard(fixture.equipmentIds.every(id=>inventory.some(item=>item.id===id && Number(item.available_quantity)>=1)),
    'Selected test equipment is available');
  return {leader,member};
}
export default function ({leader,member}) {
  const gps={latitude:fixture.latitude,longitude:fixture.longitude};
  const attendanceId=uuid();
  const noteId=uuid();
  // Log generated IDs only, so partially completed test records can be located.
  console.log(`TEST_RECORD attendance=${attendanceId} draft=${noteId}`);
  const start=call('start_shift',leader,gps);
  guard(start.schedule?.id===fixture.scheduleId,'Server selected the prepared schedule');
  guard(typeof start.qr_payload==='string','Start shift supplied QR payload');
  call('clock_in',member,{...gps,id:attendanceId,checkpoint_id:start.qr_payload,equipment:[]});
  call('log_equipment',member,{attendance_id:attendanceId,equipment:fixture.equipmentIds});
  const preview=call('return_preview',member);
  guard(preview.attendance_id===attendanceId && fixture.equipmentIds.every(id=>preview.equipment.some(e=>e.id===id)),
    'Issued equipment is linked to the new attendance');
  const end=call('end_shift',leader,gps);
  guard(typeof end.qr_payload==='string','End shift supplied QR payload');
  call('clock_out',member,{...gps,checkpoint_id:end.qr_payload,returned_equipment:fixture.equipmentIds});
  guard(call('pending_returns',leader).data.some(r=>r.id===attendanceId),'Return entered pending state');
  call('acknowledge_return',leader,{attendance_id:attendanceId});
  const completed=call('attendance_logs',leader).data.filter(r=>r.id===attendanceId);
  guard(completed.length===1 && completed[0].return_status==='completed' && Boolean(completed[0].clock_out_time),
    'Exactly one completed attendance record exists');
  const equipment=call('equipment_logs',leader).data;
  guard(equipment.some(e=>e.attendance_id===attendanceId && e.return_status==='completed' && e.returned_at && e.display_status==='Telah Dipulangkan'),
    'Grouped equipment log confirms completed return');
  call('save_assessment',leader,{schedule_id:fixture.scheduleId,user_id:member.userId,status:'present',notes:'k6 controlled test'});
  const assessmentEndpoint={...byId.assessment,path:byId.assessment.path+'?schedule_id='+encodeURIComponent(fixture.scheduleId)};
  const assessed=requireOK(request(assessmentEndpoint,leader),'assessment verification');
  guard(assessed.members.some(m=>m.user_id===member.userId && m.assessment_status==='present' && m.is_acknowledged),
    'Present assessment was persisted');
  call('draft_note',member,{...gps,id:noteId,title:'K6 TEST - draft only',description:'Controlled API test record; no operational incident.',
    category:fixture.noteCategory,location_name:'Prepared test location',reported_to:''});
  guard(call('notes',member).data.some(n=>n.id===noteId && n.status==='Pending'),'Draft note was persisted as Pending');
  flowCompleted.add(1);
  console.log('Controlled flow finished. Test attendance, assessment and draft are retained for review; no automatic deletion.');
}
export function handleSummary(data) {
  return report(data,endpoints,'One sequential controlled write flow with one leader and one patroller. Timing observations only; this is NOT concurrent write load evidence. No photograph upload, emergency submission, registration, destructive administration or notification deletion is performed. Retained test records require review. Failed flows can leave partial records; do not blindly rerun.');
}
