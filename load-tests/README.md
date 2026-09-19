# iRonda API testing

Prepared from the Flutter source and the local cPanel recovery backend dated 8 September 2026. The live deployment has not been inspected by these preparation steps. Scripts are prepared, not executed against the server. The existing report and baseline script are unchanged.

## Fastest useful run

Open PowerShell in this folder and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-tests.ps1 -Mode quick
```

This execution-policy setting applies to that PowerShell process only. It does not change the machine's saved policy. You enter five passwords locally, masked; no credentials are written to a file. If all five test accounts use the same password, add `-SharedPassword` to enter it once. Account emails and expected roles are in accounts.json; roles are checked against the actual login response. Edit that file if a supplied account has a different role.

Quick mode runs these separately:

1. **smoke:** one active VU visits every eligible account/endpoint pair once, pausing 0.5 seconds between requests. Five serial setup logins. It stops the sequence if a login or application check fails. Usually around 2 minutes, but slow responses can take longer (10-minute cap).
2. **load:** five VUs use five distinct accounts concurrently for 3 minutes. Each VU rotates through the endpoints allowed for its role, with 1 second between requests. Login occurs once per account, serially, before the load window. This is a synthetic endpoint rotation, not measured real-user behaviour or a claim of realistic polling intervals. No load ramp: fixed five-user workload.
3. **login:** five accounts repeatedly log in concurrently for 1 minute, with 5 seconds between each account's attempts. Separate login-workload evidence; does not represent ordinary session behaviour. Five serial preflight logins are included in its login totals.

Allow roughly 6-8 minutes plus password entry; slow responses can extend this. Do not increase VUs by reusing the same accounts and then report them as distinct people. Five is the largest distinct-user workload supported by the supplied accounts. If the server cannot serve this workload, keep the failures; do not label the system as passed.

Performance threshold failures are retained and quick mode continues to its next phase. A failed smoke preflight or runtime error stops it. Passwords are removed from the temporary environment when the runner finishes. No web request is made until you run the commands.

Individual phases: replace `quick` with `smoke`, `load`, or `login`. Optional `baseline` runs three sequential sweeps with one active VU; it may take several minutes. This baseline is exploratory and still uses small samples per endpoint.

## Results to send back

Each phase creates its own timestamped folder under results/:

- results.md: endpoint table suitable for interpreting and subsequently adding to Chapter 6.
- results.json: structured results, sample counts and empty-response counts.
- dashboard.html: built-in k6 performance dashboard export; open in your browser.
- metrics.json: raw time-series metrics with endpoint, role and account-label tags. No request/response bodies are exported.
- run-manifest.json, completion.json, and source snapshots: environment/date/version, exit status and the exact scripts used.

Keep each phase separate. Per-endpoint means/p95 and failures are not mixed between smoke, load and login. Request duration is the HTTP sending/waiting/receiving duration; it excludes phone UI, OCR, camera, and PDF construction. Standard raw k6 metrics also retain connection/TLS timing for diagnosis.

The targets are p95 < 2000 ms for regular API requests, p95 < 5000 ms for monthly report API requests, and HTTP failures < 1%. Application/shape checks require 100% success, including a body with status=success. Non-JSON errors are recorded as failures and still get a pause. Smoke and controlled writes report correctness checks and observed timings only. Empty lists are allowed but their counts are disclosed: an empty table cannot establish populated-data performance. Fewer than 20 samples receive an exploratory warning; 20 or more still does not establish statistical confidence or capacity.

Watch cPanel Resource Usage during the run and capture the time interval afterward. Note the network used, test date/time, cPanel CPU/memory/process limits, relevant data volumes, and the deployed code version if known. Do not infer the cause of slow requests from client timings alone.

## What is covered

catalog.js lists 21 GET request variants plus login. They span profile, location list, personal schedules, active attendance, inventory, notes, incident feed, notifications, SOS polling, dashboard statistics, members, squads, administrative schedules, attendance logs, pending returns, equipment logs, attendance assessment retrieval, active shifts, monthly report data, super-admin overview and administrative locations.

Roles are deliberately restricted to relevant app workflows. A 403 response is a failure of the intended positive test, not silently counted as success. This is not a permissions/security audit. GET success checks establish basic response shape, not correctness of every field or district boundary. Empty lists and small datasets must be stated in the report. SOS polling measures only its API response, not alert submission-to-receipt delay.

## Controlled attendance/equipment/write flow (separate, optional execution)

The file patrol-write.js is ready for a **single sequential functional/timing run**, not concurrent write testing. Before running it:

1. Use a test-only squad with the supplied leader and patroller. Both must have no active or pending attendance. Prepare exactly one fresh schedule for today (Malaysia time) in this squad, without earlier attendance or assessments.
2. Copy patrol-fixture.example.json to patrol-fixture.local.json. Enter the actual squad/schedule IDs, the prepared test coordinates, at least one available test equipment ID (strings), and a supported non-emergency note category. Set testRecordsOnly to true only for the prepared test data. Do not use Kecemasan.
3. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\run-tests.ps1 -Mode writes`.

The flow verifies prerequisites, starts the leader's shift, uses its fresh QR payload to check in the patroller, issues the selected equipment, verifies the return preview, ends the leader's shift, submits patroller return with the fresh OUT QR, checks the pending record, acknowledges the return, checks completed attendance and the grouped equipment log, saves/verifies a Present assessment, and saves/verifies one Pending daily-note draft.

It creates real test attendance, assessment and note records on the configured hosting. It retains those records as evidence and logs generated record IDs. There is no automatic deletion or rollback across endpoints. If it fails halfway, inspect and resolve partial records through the application before repeating with a fresh test schedule. A timed-out write may have succeeded server-side. QR expiry or changed server behaviour can cause real failures; do not turn them into assumed passes.

This is simulated API location input and QR submission, not device GPS or camera validation. Equipment verification uses the backend's grouped return response, not a direct audit of every database row. No image file is attached to the note, so this does not establish photograph-upload performance.

## Scope not automated here

See endpoint-coverage.md for every PHP endpoint in the inspected bundle. Registration/verification, password/profile changes, destructive administration, notification mutations, incident submission/status/deletion, emergency submission and photo uploads need their own prepared fixtures and dedicated cases. They are not covered by the five-user read test. A generic request flood would mostly measure invalid requests or change shared records, so it is not valid evidence for these flows.

No new claim that all 19 modules or all API endpoints passed may be added from this package. Existing functional evidence can remain alongside these additional performance results. Add testing methodology/results/limitations to the report only; do not rewrite its grammar or formatting. No new results have been fabricated or inserted.
