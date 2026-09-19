// Local-only verification. HTTP is mocked: this program cannot contact iRonda.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const root=path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1'));
const accounts=JSON.parse(fs.readFileSync(path.join(root,'accounts.json'),'utf8'));
const fixture={leaderLabel:'leader-alpha',patrollerLabel:'patroller-ali',squadId:'test-squad',scheduleId:'test-schedule',latitude:2.1,longitude:102.1,equipmentIds:['eq1'],noteCategory:'Test note',testRecordsOnly:true};
async function harness(mode, fault) {
  const values={}, calls=[], sleeps=[], logs=[];
  let context, namespace, attendanceId, draftId, finished=false, assessed=false;
  const actorFor=(params)=>accounts.find(a=>`Bearer MOCK-${a.label}`===params.headers.Authorization);
  function httpCall(method,url,body,params) {
    const endpoint=params.tags.name;
    calls.push({method,endpoint,account:params.tags.account,role:params.tags.role});
    let response={status:'success',data:[]};
    const payload=typeof body==='string'?JSON.parse(body):body;
    if (endpoint==='login') {
      const a=accounts.find(a=>a.email===payload.email);
      response={status:'success',token:`MOCK-${a.label}`,data:{id:a.label,role:fault==='role'?'wrong':a.role}};
    } else {
      const e=namespace.reads.find(e=>e.id===endpoint);
      if (e) {
        assert(e.roles.includes(actorFor(params).role),`Unauthorized role route ${endpoint}`);
        const shape=e.shape==='array'?[]:e.shape==='boolean'?false:{};
        const parts=e.field.split('.'); let obj=response;
        for(const key of parts.slice(0,-1)) obj=obj[key]={};
        obj[parts.at(-1)]=shape;
      }
      const today=new Date(Date.now()+8*3600000).toISOString().slice(0,10);
      if(endpoint==='schedule') Object.assign(response,{squad:{squad_id:'test-squad'},schedules:[{id:'test-schedule',shift_date:today,start_time:'20:00:00'}]});
      if(endpoint==='inventory') response.data=[{id:'eq1',available_quantity:2}];
      if(endpoint==='start_shift') Object.assign(response,{schedule:{id:'test-schedule'},qr_payload:'MOCK-IN'});
      if(endpoint==='clock_in') attendanceId=payload.id;
      if(endpoint==='end_shift') response.qr_payload='MOCK-OUT';
      if(endpoint==='return_preview') Object.assign(response,{attendance_id:attendanceId,equipment:[{id:'eq1'}]});
      if(endpoint==='pending_returns') response.data=attendanceId?[{id:attendanceId}]:[];
      if(endpoint==='acknowledge_return') finished=true;
      if(endpoint==='attendance_logs') response.data=finished?[{id:attendanceId,schedule_id:'test-schedule',return_status:'completed',clock_out_time:'now'}]:[];
      if(endpoint==='equipment_logs') response.data=finished?[{attendance_id:attendanceId,return_status:'completed',returned_at:'now',display_status:'Telah Dipulangkan'}]:[];
      if(endpoint==='save_assessment') assessed=true;
      if(endpoint==='assessment') Object.assign(response,{schedule:{id:'test-schedule'},members:assessed?[{user_id:'patroller-ali',assessment_status:'present',is_acknowledged:true}]:[]});
      if(endpoint==='draft_note') draftId=payload.id;
      if(endpoint==='notes') response.data=draftId?[{id:draftId,status:'Pending'}]:[];
    }
    return {status:fault==='http'&&endpoint!=='login'?503:200,timings:{duration:100},json:()=>{
      if(fault==='json'&&endpoint!=='login') throw new Error('Mock invalid JSON');
      if(fault==='app'&&endpoint!=='login') return {status:'error'};
      return response;
    }};
  }
  class Metric {
    constructor(name){this.name=name;values[name]=[];}
    add(value){values[this.name].push(Number(value));}
  }
  context=vm.createContext({console:{log:(s)=>logs.push(s),warn:(s)=>logs.push(s)},__VU:1,
    __ENV:{IRONDA_MODE:mode,IRONDA_CREDENTIALS:JSON.stringify(accounts.map(a=>({email:a.email,password:'MOCK-PASSWORD'})))},
    open:(file)=>file.includes('patrol-fixture')?JSON.stringify(fixture):fs.readFileSync(path.join(root,file),'utf8')});
  const cache=new Map();
  const mocks={
    'k6/http':{default:{get:(u,p)=>httpCall('GET',u,null,p),post:(u,b,p)=>httpCall('POST',u,b,p)}},
    'k6':{check:(v,checks)=>Object.values(checks).map(fn=>fn(v)).every(Boolean),fail:s=>{throw new Error(s);},sleep:s=>sleeps.push(s)},
    'k6/metrics':{Trend:Metric,Rate:Metric,Counter:Metric},
  };
  async function load(file) {
    if(cache.has(file)) return cache.get(file);
    const module=mocks[file]?new vm.SyntheticModule(Object.keys(mocks[file]),function(){for(const [k,v]of Object.entries(mocks[file]))this.setExport(k,v);},{context,identifier:file})
      :new vm.SourceTextModule(fs.readFileSync(path.join(root,file),'utf8'),{context,identifier:file});
    cache.set(file,module);
    await module.link(s=>load(s.startsWith('./')?s.slice(2):s));
    return module;
  }
  const catalog=await load('catalog.js');await catalog.evaluate();namespace=catalog.namespace;
  const name=mode==='writes'?'patrol-write.js':mode==='login'?'login-load.js':'ironda-suite.js';
  const module=await load(name);await module.evaluate();
  return {context,api:module.namespace,catalog:namespace,calls,sleeps,values,logs,
    summary:()=>({metrics:Object.fromEntries(Object.entries(values).map(([name,arr])=>[name,{values:{count:arr.reduce((a,b)=>a+b,0),rate:arr.length?arr.reduce((a,b)=>a+b,0)/arr.length:0,avg:100,'p(95)':100,max:100}}]))})};
}
const smoke=await harness('smoke');const actors=smoke.api.setup();smoke.api.default(actors);
assert.equal(smoke.calls.filter(c=>c.endpoint==='login').length,5);
assert.equal(new Set(smoke.calls.filter(c=>c.method==='GET').map(c=>c.endpoint)).size,21);
assert.equal(smoke.sleeps.length,smoke.calls.length-5);
for(const fault of ['json','http','app']) {
  const h=await harness('load',fault);const a=h.api.setup();h.api.default(a);
  assert.equal(h.sleeps.length,1,`${fault}: retain pause`);
  assert.equal(h.values.errors_profile[0],1,`${fault}: record failure`);
}
const bad=await harness('smoke','role');assert.throws(()=>bad.api.setup(),/role verification/);
assert.equal(bad.calls.length,1,'Stop before workload after login role mismatch');
const load=await harness('load');const users=load.api.setup();
for(let i=1;i<=5;i++){load.context.__VU=i;load.api.default(users);}
assert.equal(new Set(load.calls.filter(c=>c.method==='GET').map(c=>c.account)).size,5);
const summary=load.api.handleSummary(load.summary());
assert(!JSON.stringify(summary).includes('MOCK-PASSWORD'));
assert(!JSON.stringify(summary).includes('MOCK-'));
assert(Object.values(summary).some(s=>s.includes('NOT RUN')),'No samples must not appear as passes');
const write=await harness('writes');const participants=write.api.setup();write.api.default(participants);
assert.equal(new Set(write.calls.filter(c=>c.method==='POST'&&c.endpoint!=='login').map(c=>c.endpoint)).size,8);
assert.equal(write.values.flow_completed[0],1,'Entire controlled flow completed');
assert(!write.calls.some(c=>/delete|sos|register/.test(c.endpoint)),'No destructive or emergency writes');
assert(!write.logs.some(s=>s.includes('MOCK-PASSWORD')||s.includes('MOCK-')));
const login=await harness('login');login.api.setup();login.api.default();assert.equal(login.sleeps[0],5);
console.log('PASS: 21 read routes, role mapping, five unique accounts, failure accounting/pacing, safe summary, eight-step write flow, login pacing. All HTTP calls were mocks.');
