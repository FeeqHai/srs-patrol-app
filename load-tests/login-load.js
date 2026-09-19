import { sleep } from 'k6';
import { accounts, loginAll, request, thresholds, report } from './common.js';
import { loginEndpoint } from './catalog.js';
export const options = {vus:accounts.length,duration:'1m',setupTimeout:'2m',thresholds:thresholds([loginEndpoint])};
export function setup() { loginAll(); }
export default function () {
  const credentials = JSON.parse(__ENV.IRONDA_CREDENTIALS);
  const account = accounts[__VU-1];
  try {
    request(loginEndpoint,account,credentials[__VU-1],false,d =>
      Boolean(d?.token) && d?.data?.role === account.role);
  } finally { sleep(5); }
}
export function handleSummary(data) {
  return report(data,[loginEndpoint],`${accounts.length} distinct accounts repeatedly log in for 1 minute with a 5-second pause each. Includes ${accounts.length} serial setup logins. This is an explicit login workload, not ordinary session behaviour.`);
}
