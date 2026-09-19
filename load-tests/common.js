import http from 'k6/http';
import { check, fail } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';
import { catalog, loginEndpoint } from './catalog.js';

export const base = 'https://api.ironda.app/srs_api/';
export const accounts = JSON.parse(open('./accounts.json'));
export const mode = __ENV.IRONDA_MODE || 'smoke';
export const flowCompleted = new Counter('flow_completed');
export const metrics = Object.fromEntries(catalog.map(e => [e.id, {
  duration: new Trend(`duration_${e.id}`, true),
  count: new Counter(`requests_${e.id}`),
  http: new Rate(`http_errors_${e.id}`),
  app: new Rate(`errors_${e.id}`),
  empty: new Counter(`empty_${e.id}`),
}]));
export function thresholds(endpoints, performance = true) {
  const result = {checks:['rate==1']};
  for (const e of endpoints) {
    result[`errors_${e.id}`] = ['rate==0'];
    result[`http_errors_${e.id}`] = ['rate<0.01'];
    if (performance) result[`duration_${e.id}`] = [`p(95)<${e.limit}`];
  }
  return result;
}
export function at(obj, path) {
  return path.split('.').reduce((o,k) => o == null ? undefined : o[k], obj);
}
export function request(e, actor, body, json = false, validate = () => true) {
  const params = {timeout:'15s',redirects:0,tags:{name:e.id,role:actor?.role || 'login',account:actor?.label || 'login'},headers:{}};
  if (actor?.token) params.headers.Authorization = `Bearer ${actor.token}`;
  if (json) params.headers['Content-Type'] = 'application/json';
  const r = e.method === 'POST'
    ? http.post(base+e.path, json ? JSON.stringify(body) : body, params)
    : http.get(base+e.path, params);
  let data = null;
  try { data = r.json(); } catch (_) { /* A non-JSON response is a failed check. */ }
  const field = e.field ? at(data,e.field) : undefined;
  const shapeOK = !e.field || (e.shape === 'array' ? Array.isArray(field)
    : e.shape === 'boolean' ? typeof field === 'boolean'
    : field !== null && typeof field === 'object');
  let validationOK = false;
  try { validationOK = Boolean(validate(data)); } catch (_) { validationOK = false; }
  const httpOK = r.status === 200;
  const ok = check(r, {
    [`${e.id}: HTTP 200`]: () => httpOK,
    [`${e.id}: valid application response`]: () => data?.status === 'success' && shapeOK && validationOK,
  });
  const m = metrics[e.id];
  m.count.add(1); m.duration.add(r.timings.duration); m.http.add(!httpOK); m.app.add(!ok);
  if (Array.isArray(field) && field.length === 0) m.empty.add(1);
  // Never print response bodies, credentials, JWTs or personal records.
  if (!ok) console.warn(`${e.id}: failed, HTTP ${r.status}, account ${actor?.label || 'login'}`);
  return {ok,data};
}
export function loginAll() {
  const credentials = JSON.parse(__ENV.IRONDA_CREDENTIALS || '[]');
  if (!accounts.length || !Array.isArray(credentials) || credentials.length !== accounts.length) {
    fail(`Credential handoff mismatch: expected ${accounts.length} accounts, received ${Array.isArray(credentials) ? credentials.length : 'invalid format'}. Rerun the updated run-tests.ps1.`);
  }
  if (credentials.some((c,i) => typeof c.email !== 'string' || c.email !== accounts[i].email || typeof c.password !== 'string' || !c.password)) {
    fail('Credentials must contain one matching email and a nonempty password per account. No login requests were sent.');
  }
  if (new Set(accounts.map(a => a.email.toLowerCase())).size !== accounts.length) fail('Each account must be distinct.');
  return accounts.map((a,i) => {
    const result = request(loginEndpoint,a,credentials[i],false,d =>
      typeof d?.token === 'string' && d.token.length > 0 && d?.data?.role === a.role && Boolean(d?.data?.id));
    if (!result.ok) fail(`Login/role verification failed for ${a.label}; no workload started.`);
    return {...a,token:result.data.token,userId:result.data.data.id};
  });
}
export function requireOK(result, label) {
  if (!result.ok) fail(`${label} failed. Stop and inspect test records before repeating the write test.`);
  return result.data;
}
export function report(data, endpoints, details) {
  const rows = endpoints.map(e => {
    const count = data.metrics[`requests_${e.id}`]?.values?.count || 0;
    const duration = data.metrics[`duration_${e.id}`]?.values || {};
    const errors = data.metrics[`errors_${e.id}`]?.values?.rate ?? null;
    const httpErrors = data.metrics[`http_errors_${e.id}`]?.values?.rate ?? null;
    return {endpoint:e.id,path:e.path,method:e.method,requests:count,
      average_ms:count ? duration.avg : null,p95_ms:count ? duration['p(95)'] : null,
      max_ms:count ? duration.max : null,http_failure_rate:httpErrors,application_failure_rate:errors,
      empty_responses:data.metrics[`empty_${e.id}`]?.values?.count || 0,
      result: !count ? 'NOT RUN' : errors > 0 ? 'FAILED CHECKS'
        : mode === 'smoke' || mode === 'writes' ? 'CHECKS PASSED; TIMING OBSERVATION ONLY'
        : duration['p(95)'] < e.limit && httpErrors < .01 ? 'WITHIN TARGET' : 'TARGET MISSED',
      evidence: count < 20 ? 'Small sample; exploratory only' : 'Limited workload; not a capacity guarantee'};
  });
  const output = __ENV.IRONDA_OUTPUT || '.';
  const checks = data.metrics.checks?.values || null;
  const thresholdFailures = Object.entries(data.metrics).flatMap(([name,m]) =>
    Object.entries(m.thresholds || {}).filter(([,t])=>t.ok===false).map(([rule])=>`${name}: ${rule}`));
  const flowComplete = (data.metrics.flow_completed?.values?.count || 0) === 1;
  const overall = mode === 'writes' && !flowComplete ? 'INCOMPLETE WRITE FLOW'
    : checks?.rate !== 1 || thresholdFailures.length ? 'CHECK OR THRESHOLD FAILURE / VERIFY COMPLETION'
    : 'RECORDED CHECKS AND CONFIGURED THRESHOLDS PASSED';
  const clean = {mode,base_url:base,completed_utc:new Date().toISOString(),accounts:accounts.map(a=>({label:a.label,role:a.role})),
    overall,checks,threshold_failures:thresholdFailures,controlled_flow_completed:mode==='writes'?flowComplete:null,details,rows};
  const md = `# iRonda ${mode} results\n\nOverall: ${overall}. Confirm completion.json exit status and NOT RUN rows before reporting coverage.\n\n${details}\n\n` +
    '| Endpoint | Requests | Mean ms | p95 ms | HTTP failures | App/check failures | Result |\n|---|---:|---:|---:|---:|---:|---|\n' +
    rows.map(r=>`| ${r.endpoint} | ${r.requests} | ${r.average_ms?.toFixed(1) ?? '-'} | ${r.p95_ms?.toFixed(1) ?? '-'} | ${r.http_failure_rate === null ? '-' : (100*r.http_failure_rate).toFixed(2)+'%'} | ${r.application_failure_rate === null ? '-' : (100*r.application_failure_rate).toFixed(2)+'%'} | ${r.result} |`).join('\n') +
    '\n\nEmpty lists are valid but do not prove populated-data performance. Inspect results.json for sample warnings and empty-response counts. SOS API timing does not measure end-to-end alert delivery.\n';
  return {stdout:md+'\n', [`${output}/results.json`]:JSON.stringify(clean,null,2), [`${output}/results.md`]:md};
}
