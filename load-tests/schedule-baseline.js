import http from 'k6/http';
import { check, fail, sleep } from 'k6';

const BASE_URL = 'https://api.ironda.app/srs_api/';

export const options = {
  vus: 1,
  duration: '1m',
  thresholds: {
    checks: ['rate==1'],
  },
};

function readJson(response) {
  try {
    return response.json();
  } catch {
    return null;
  }
}

export function setup() {
  if (!__ENV.IRONDA_TEST_EMAIL || !__ENV.IRONDA_TEST_PASSWORD) {
    fail('Test email or password is missing.');
  }

  const response = http.post(
    `${BASE_URL}auth/login.php`,
    {
      email: __ENV.IRONDA_TEST_EMAIL,
      password: __ENV.IRONDA_TEST_PASSWORD,
    },
    { timeout: '15s', redirects: 0 }
  );

  const body = readJson(response);

  const loginPassed = check(response, {
    'Login returns HTTP 200': (r) => r.status === 200,
    'Login succeeds': () => body?.status === 'success',
    'Login provides a token': () =>
      typeof body?.token === 'string' && body.token.length > 0,
  });

  if (!loginPassed) {
    fail('Login failed. Check the credentials and account approval.');
  }

  return { token: body.token };
}

export default function (data) {
  const response = http.get(
    `${BASE_URL}schedules/get_user_schedule.php`,
    {
      headers: {
        Authorization: `Bearer ${data.token}`,
      },
      timeout: '15s',
      redirects: 0,
    }
  );

  const body = readJson(response);

  check(response, {
    'Schedule returns HTTP 200': (r) => r.status === 200,
    'Schedule request succeeds': () => body?.status === 'success',
    'Account has a squad': () => Boolean(body?.squad),
    'At least one schedule exists': () =>
      Array.isArray(body?.schedules) && body.schedules.length > 0,
  });

  console.log(
    `Schedule request: HTTP ${response.status}, ` +
    `${response.timings.duration.toFixed(0)} ms`
  );
  sleep(3);
}
