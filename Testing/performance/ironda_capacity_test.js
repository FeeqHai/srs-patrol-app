import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';

const baseUrl = (__ENV.BASE_URL || 'https://157-245-53-82.sslip.io/srs_api').replace(/\/$/, '');
const phase = (__ENV.TEST_PHASE || 'baseline').toLowerCase();
const stageDuration = __ENV.STAGE_DURATION || '1m';
const stableVus = Number(__ENV.STABLE_VUS || 100);
const enableWrites = (__ENV.ENABLE_SYNTHETIC_WRITES || 'false') === 'true';
const runId = (__ENV.RUN_ID || new Date().toISOString().replace(/[^0-9]/g, '')).slice(0, 20);

const acceptedWrites = new Counter('accepted_synthetic_writes');

function constantScenario(vus, duration, startTime = '0s') {
  return {
    executor: 'constant-vus',
    exec: 'mixedWorkload',
    vus,
    duration,
    startTime,
    gracefulStop: '10s',
  };
}

function sequentialStages(values) {
  const scenarios = {};
  values.forEach((vus, index) => {
    scenarios[`stage_${vus}`] = constantScenario(
      vus,
      stageDuration,
      `${index * 70}s`,
    );
  });
  return scenarios;
}

function scenariosForPhase() {
  if (phase === 'normal') return sequentialStages([10, 25, 50, 75, 100]);
  if (phase === 'stress') return sequentialStages([150, 200]);
  if (phase === 'spike') return { spike: constantScenario(stableVus * 2, '30s') };
  if (phase === 'endurance') {
    return {
      endurance: constantScenario(Math.max(1, Math.round(stableVus * 0.7)), '30m'),
    };
  }
  return { baseline: constantScenario(1, stageDuration) };
}

export const options = {
  scenarios: scenariosForPhase(),
  thresholds: {
    'http_req_duration{request_class:regular}': ['p(95)<2000'],
    'http_req_duration{request_class:upload}': ['p(95)<5000'],
    http_req_failed: ['rate<0.01'],
    checks: ['rate>0.99'],
  },
};

export function setup() {
  const email = __ENV.TEST_EMAIL || '';
  const password = __ENV.TEST_PASSWORD || '';
  if (!email || !password) return { token: null };
  const response = http.post(
    `${baseUrl}/auth/login.php`,
    { email, password },
    { tags: { request_class: 'regular', operation: 'login' } },
  );
  const valid = check(response, {
    'staging test login succeeded': (r) =>
      r.status === 200 && r.json('status') === 'success' && Boolean(r.json('token')),
  });
  if (!valid) throw new Error('Unable to authenticate the staging load-test account.');
  return { token: response.json('token') };
}

function uuidV4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (character) => {
    const random = Math.floor(Math.random() * 16);
    const value = character === 'x' ? random : (random & 0x3) | 0x8;
    return value.toString(16);
  });
}

function regularRequest(token) {
  if (token) {
    const response = http.get(`${baseUrl}/incidents/get_incidents.php`, {
      headers: { Authorization: `Bearer ${token}` },
      tags: { request_class: 'regular', operation: 'incident_list' },
    });
    check(response, {
      'regular API returned valid data': (r) =>
        r.status === 200 && r.json('status') === 'success',
    });
    return;
  }
  const response = http.get(`${baseUrl}/auth/get_locations.php?level=states`, {
    tags: { request_class: 'regular', operation: 'locations' },
  });
  check(response, {
    'public regular API returned valid data': (r) =>
      r.status === 200 && r.json('status') === 'success',
  });
}

function syntheticUpload(token) {
  const id = uuidV4();
  const response = http.post(
    `${baseUrl}/incidents/upload_incident.php`,
    {
      id,
      title: `LOADTEST_${runId}_${id}`,
      description: 'Synthetic staging-only capacity record. Safe to delete.',
      category: 'Lain-lain',
      latitude: '2.3090',
      longitude: '102.3180',
      location_name: 'STAGING LOAD TEST',
      reported_to: 'SYSTEM TEST',
    },
    {
      headers: { Authorization: `Bearer ${token}` },
      tags: { request_class: 'upload', operation: 'incident_create' },
    },
  );
  const passed = check(response, {
    'synthetic upload accepted once': (r) =>
      r.status === 200 && r.json('status') === 'success',
  });
  if (passed) acceptedWrites.add(1);
}

export function mixedWorkload(data) {
  if (enableWrites && data.token && Math.random() < 0.02) {
    syntheticUpload(data.token);
  } else {
    regularRequest(data.token);
  }
  sleep(1);
}
