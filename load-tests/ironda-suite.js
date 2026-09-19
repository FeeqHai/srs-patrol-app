import { sleep } from 'k6';
import { reads, loginEndpoint } from './catalog.js';
import { accounts, mode, request, loginAll, thresholds, report } from './common.js';

if (!['smoke','baseline','load'].includes(mode)) throw new Error('Invalid read-test mode.');
const eligible = reads.filter(e => accounts.some(a => e.roles.includes(a.role)));
export const options = {
  scenarios: mode === 'load'
    ? {mixed:{executor:'constant-vus',vus:accounts.length,duration:'3m',gracefulStop:'45s'}}
    : {sequential:{executor:'per-vu-iterations',vus:1,iterations:1,maxDuration:'10m'}},
  setupTimeout:'2m',
  thresholds: thresholds(eligible, mode !== 'smoke'),
};
export function setup() { return loginAll(); }
let cursor = 0;
export default function (actors) {
  if (mode === 'load') {
    // A unique account per VU. No account multiplication to claim extra users.
    const actor = actors[__VU-1];
    const endpoints = eligible.filter(e => e.roles.includes(actor.role));
    const endpoint = endpoints[cursor++ % endpoints.length];
    try { request(endpoint,actor); } finally { sleep(1); }
  } else {
    // A serial sweep gives every eligible endpoint/account pair a first check.
    const repeats = mode === 'baseline' ? 3 : 1;
    for (let round=0; round<repeats; round++) {
      for (const actor of actors) {
        for (const endpoint of eligible.filter(e => e.roles.includes(actor.role))) {
          try { request(endpoint,actor); } finally { sleep(.5); }
        }
      }
    }
  }
}
export function handleSummary(data) {
  return report(data,[loginEndpoint,...reads], mode === 'load'
    ? `${accounts.length} distinct concurrent accounts; 3 minutes; one API request then 1-second pause per VU. Role-based endpoint rotation is a synthetic workload, not measured real-user proportions. Login occurs serially in setup and is not a login concurrency test. Account-level results can be recovered from metrics.json tags. Some endpoints may have small samples.`
    : `One active VU visits each eligible endpoint/account pair ${mode === 'baseline' ? 'three times' : 'once'}, with a 0.5-second pause per request. Accounts log in serially during setup. This is a coverage sweep; limited samples are not capacity evidence.`);
}
