# iRonda Detailed Test Case Catalogue

Status date: 8 August 2026. `Passed` means the stated automated/local evidence exists. `Not executed` means the case requires the POCO F5, consenting participants, the isolated HTTPS staging clone, or an authorized role account. No unexecuted case is counted as a pass.

| Test case ID | Module / class | Procedure | Expected result and acceptance rule | Status | Evidence |
|---|---|---|---|---|---|
| TC-IV-001 | Consent | Open identity verification without selecting consent and attempt to continue. | Capture control remains disabled; no camera or server session starts. | Not executed | POCO F5 screen recording required. |
| TC-IV-002 | Platform control | Open registration on web/non-Android build. | The page directs the applicant to Android; there is no verification bypass. | Not executed | Web manual test required. |
| TC-IV-003 | MyKad OCR | Process synthetic OCR containing a valid name, IC and Melaka address. | Name, 12-digit IC and state are extracted correctly. | Passed | `mykad_parser_test.dart`. |
| TC-IV-004 | IC validation | Process OCR containing an impossible birth month or fewer than 12 digits. | Parser rejects the record. | Passed | Flutter and PHP unit tests. |
| TC-IV-005 | Image resolution | Supply a low-resolution portrait document image. | Image is rejected for resolution and orientation. | Passed | `image_quality_analyzer_test.dart`. |
| TC-IV-006 | Glare | Supply an overexposed white document image. | Glare fraction exceeds the limit and capture is rejected. | Passed | `image_quality_analyzer_test.dart`. |
| TC-IV-007 | Focus | Capture an intentionally blurred MyKad. | Focus score is below the limit and the user is asked to retry. | Not executed | Real camera image required. |
| TC-IV-008 | Card portrait | Capture a MyKad containing zero or more than one detected portrait. | Capture is rejected; exactly one portrait is required. | Not executed | Consented/synthetic document images required. |
| TC-IV-009 | State availability | Scan a MyKad whose address state is outside configured active states. | Registration stops with an operational-area explanation. | Not executed | POCO F5 and safe test card required. |
| TC-IV-010 | Neutral selfie | Capture no face, multiple faces or a very small face. | Selfie is rejected. | Not executed | POCO F5 camera test required. |
| TC-IV-011 | Blink liveness | Receive the blink challenge, capture closed eyes, then repeat with open eyes. | Closed-eye capture passes; open-eye capture fails. | Not executed | POCO F5 camera test required. |
| TC-IV-012 | Head-turn liveness | Receive the head-turn challenge, capture yaw ≥18°, then repeat facing forward. | Head turn passes; forward-facing challenge fails. | Not executed | POCO F5 camera test required. |
| TC-IV-013 | Face similarity | Compare same-person and different-person MyKad/selfie pairs. | Same-person genuine acceptance and different-person rejection meet the evaluation targets selected from the consented dataset. | Not executed | Consented evaluation dataset required; threshold must be calibrated. |
| TC-IV-014 | Embedding calculation | Compare identical, orthogonal, negative and mismatched vector fixtures. | Cosine calculation returns bounded, deterministic scores. | Passed | `face_similarity_test.dart`. |
| TC-IV-015 | Temporary data | Complete, fail, cancel and leave each capture stage; inspect application cache and network traffic. | IC/selfie files are removed; images and embeddings are not transmitted or retained. | Not executed | POCO F5 storage/network inspection required. |
| TC-IV-016 | Session start | Start with consent, a valid 12-digit IC and installation ID. | A 15-minute session and opaque one-time token are returned; only hashes are stored for IC/device/IP. | Passed | PHP integration test and database inspection. |
| TC-IV-017 | No-token registration | Call registration without a verification token. | Request is rejected and no user is inserted. | Passed | `register_without_token_rejected`. |
| TC-IV-018 | Verified registration | Complete a passing session and submit valid manual details. | A pending patroller is created with verified status/method/time. | Passed | `verified_pending_user_created_with_locked_name`. |
| TC-IV-019 | Locked identity fields | Omit or tamper with client name and state during registration. | Server uses verified session name and rejects a state mismatch. | Partly passed | Name locking passed; explicit state-tamper case remains not executed. |
| TC-IV-020 | Token reuse | Delete the test user and retry registration with the consumed token. | Reuse is rejected. | Passed | `consumed_token_reuse_rejected`. |
| TC-IV-021 | Token/IC binding | Complete a token for IC A and register IC B. | Registration is rejected without exposing either IC in logs. | Not executed | API negative integration case to run on staging. |
| TC-IV-022 | Expiry | Move a started/verified session beyond its 15-minute expiry and retry. | Session is expired and cannot be completed or consumed. | Not executed | Time-controlled API test required. |
| TC-IV-023 | Cooldown | Fail three complete verification attempts and immediately start a fourth. | Backend returns a 30-minute cooldown and zero attempts remaining. | Passed | `three_failures_enforce_30_minute_cooldown`. |
| TC-IV-024 | Endpoint rate limit | Exceed start, complete and registration per-IP limits inside one hour. | Requests beyond limits are rejected without database/resource exhaustion. | Not executed | Isolated staging security test required. |
| TC-IV-025 | Existing users | Log in with an account created before the migration. | Existing `legacy` account remains valid and is not forced through re-verification. | Not executed | Authorized legacy account required. |
| TC-REG-001 | Manual fields | After verification, enter phone, email, password, District (sub-district) and zone. | Editable fields accept valid values while name, IC and state remain locked. | Not executed | POCO F5 workflow test required. |
| TC-REG-002 | Location hierarchy | Submit a zone that does not belong to the chosen district/state. | Backend rejects the impossible hierarchy. | Not executed | API negative integration case required. |
| TC-REG-003 | Duplicate identity | Register an existing IC or email. | Duplicate request is rejected and no duplicate row exists. | Not executed | Staging fixture required. |
| TC-REG-004 | KRT approval | Approve a pending patroller as the correct KRT Administrator. | Account becomes active within the administrator's location scope. | Not executed | KRT administrator UAT account required. |
| TC-SEC-001 | Release transport | Install release APK and inspect all registration requests. | All requests use valid HTTPS; Android rejects cleartext. | Not executed | HTTPS staging deployment required. |
| TC-SEC-002 | Session persistence | Inspect `registration_verifications` before/after successful registration. | Temporary row is removed after consumption; only account status/method/time remain. | Passed | Local database integration inspection. |
| TC-SEC-003 | Static analysis | Run full Dart analyzer and PHP syntax checks. | Zero Dart issues and zero PHP syntax errors. | Passed | Analyzer and `php -l` outputs, 8 August 2026. |
| TC-BLD-001 | Android build | Produce an Android debug APK with API 26 minimum. | Gradle completes and APK is generated. | Passed | `build/app/outputs/flutter-apk/app-debug.apk`. |
| TC-WDG-001 | App smoke | Pump the application through the splash sequence. | Material app boots and leaves no pending timer. | Passed | `widget_test.dart`. |
| TC-API-001 | API integration | Start, complete and consume a verification session. | All steps succeed exactly once and the account is pending. | Passed | PHP integration test. |
| TC-ROLE-001 | Patroller authorization | Attempt leader/admin-only operations as patroller. | Protected routes return 403 and no data changes. | Not executed | Staging role suite required. |
| TC-ROLE-002 | KRT location scope | Access users from another district as KRT Administrator. | Cross-district access is denied. | Not executed | Multi-location staging fixtures required. |
| TC-ROLE-003 | System administrator | Access authorized multi-location reporting as Administrator. | Authorized reporting works without exposing full IC values. | Not executed | Administrator UAT account required. |
| TC-FUN-001 | Login | Test valid, invalid, pending and inactive accounts. | Only valid active credentials create a session. | Not executed | Functional staging cycle required. |
| TC-FUN-002 | Patrol scheduling | Create, view and update a schedule with role/location checks. | Authorized users see consistent schedule data. | Not executed | Functional staging cycle required. |
| TC-FUN-003 | Attendance | Start/end patrol attendance and inspect duplicate prevention. | One consistent attendance lifecycle is stored. | Not executed | Functional staging cycle required. |
| TC-FUN-004 | Incident / daily note | Submit a synthetic report, retrieve it, then remove the fixture. | One complete, non-corrupt record and intended notifications exist. | Not executed | Isolated staging write test required. |
| TC-FUN-005 | SOS | Trigger a controlled SOS fixture and verify scoped recipients. | Intended recipients receive one alert; unauthorized users do not. | Not executed | Supervised staging test required. |
| TC-FUN-006 | Notifications | Read, mark read and remove a notification. | State changes are consistent for the owning user only. | Not executed | Functional staging cycle required. |
| TC-REGRESS-001 | Core regression | Repeat login, schedules, attendance, incidents, SOS, profiles, notifications and administration after IC feature integration. | No previously accepted critical workflow regresses. | Not executed | Full regression cycle required. |
| TC-PERF-001 | Local harness | Run read-only stages from 1 to 200 clients against local XAMPP. | Harness records complete requests, p95, throughput and error rate. | Passed (preliminary only) | `local_preliminary_capacity.csv`. |
| TC-PERF-002 | Formal normal load | Run 10, 25, 50, 75 and 100 VUs against staging from a separate generator. | Every stable stage meets both p95 limits, <1% errors, data integrity and resource safety. | Not executed | HTTPS staging and k6 generator required. |
| TC-PERF-003 | Stress | Run 150 and 200 VUs or stop at safety threshold. | First failed threshold identifies the boundary without damaging staging. | Not executed | HTTPS staging and monitoring required. |
| TC-PERF-004 | Spike | Run twice the highest stable VU count. | Recovery and threshold behavior are recorded. | Not executed | Stable capacity required first. |
| TC-PERF-005 | Endurance | Run 30 minutes at about 70% stable capacity. | No rising errors, resource leak or data corruption. | Not executed | Stable capacity and monitoring required. |
| TC-UAT-001 | UAT and SUS | Run assigned tasks with 12 anonymized target participants. | ≥90% task completion, mean ≥4.0/5, SUS ≥68 and no unresolved critical defect. | Not executed | Human participation required. |
