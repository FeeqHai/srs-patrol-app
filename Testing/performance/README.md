# iRonda capacity test execution

The evaluator's “how many users” question is answered by **concurrent-user capacity testing**. The supported capacity is the highest completed stage that satisfies all response, error, integrity, and server-resource thresholds.

Run the formal test only against the isolated staging clone, from a separate load-generator machine. Do not run it against the public demo or production database.

Required phases:

1. `TEST_PHASE=baseline`: 1 virtual user.
2. `TEST_PHASE=normal`: 10, 25, 50, 75, and 100 virtual users.
3. `TEST_PHASE=stress`: 150 and 200 virtual users, stopping if server safety limits are reached.
4. `TEST_PHASE=spike` with `STABLE_VUS`: twice the highest stable stage.
5. `TEST_PHASE=endurance` with `STABLE_VUS`: 30 minutes at approximately 70% of stable capacity.

Example PowerShell command after k6 is installed on the load generator:

```powershell
$env:BASE_URL='https://157-245-53-82.sslip.io/srs_api'
$env:TEST_EMAIL='<staging-test-account>'
$env:TEST_PASSWORD='<staging-test-password>'
$env:TEST_PHASE='normal'
$env:ENABLE_SYNTHETIC_WRITES='true'
$env:RUN_ID='FORMAL_YYYYMMDD_A'
k6 run --summary-export normal-summary.json .\ironda_capacity_test.js
```

Before and during every stage, record CPU, RAM, Apache workers, PHP usage, MariaDB connections, disk capacity, and database errors from the staging server. Compare `accepted_synthetic_writes` with the number of `incidents.title` values beginning with the exact `LOADTEST_<RUN_ID>_` prefix; confirm unique IDs and valid rows before deleting that synthetic prefix.

The pass limits are:

- regular API p95 below 2,000 ms;
- upload/report p95 below 5,000 ms;
- HTTP failure rate below 1%;
- check rate above 99%;
- no lost, duplicate, or corrupted records;
- no unsafe resource exhaustion.

The local ApacheBench script is read-only and exists only to validate the load-generator mechanics. Its results are not the supported capacity of the DigitalOcean environment.
