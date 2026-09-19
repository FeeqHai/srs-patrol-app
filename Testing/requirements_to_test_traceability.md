# Requirements-to-Test Traceability Matrix

| Requirement | Verification test cases | Current coverage |
|---|---|---|
| New patroller must consent before identity processing. | TC-IV-001 | Manual device case not executed. |
| MyKad must be readable, in focus, correctly oriented, visible and contain one portrait. | TC-IV-003–TC-IV-008 | Parser, resolution and glare automated; real camera cases pending. |
| Name, IC and state must be extracted and locked. | TC-IV-003, TC-IV-009, TC-IV-018, TC-IV-019 | Extraction and server name locking passed; device/state tamper pending. |
| Live face must complete a randomized blink or head-turn action. | TC-IV-010–TC-IV-012 | Device execution pending. |
| MyKad portrait and selfie must be compared on-device. | TC-IV-013–TC-IV-014 | Similarity calculation passed; biometric calibration pending. |
| Raw images and embeddings must not be transmitted or retained. | TC-IV-015, TC-SEC-002 | Server session cleanup passed; device/network inspection pending. |
| Applicant manually enters phone, email, password, District/sub-district and zone. | TC-REG-001 | Device workflow pending. |
| Verified application becomes pending for KRT Administrator approval. | TC-IV-018, TC-REG-004 | Pending creation passed; approval UAT pending. |
| Three failures enforce a 30-minute cooldown with no bypass. | TC-IV-017, TC-IV-020–TC-IV-023 | No-token, reuse and cooldown passed; expiry/binding pending. |
| Registration and verification endpoints are rate limited. | TC-IV-024 | Implemented; isolated threshold execution pending. |
| Release traffic uses HTTPS. | TC-SEC-001 | Release manifest configured; server deployment pending. |
| Existing users remain valid without compulsory re-verification. | TC-IV-025 | Migration defaults to `legacy`; login regression pending. |
| Existing core modules must not regress. | TC-ROLE-001–TC-REGRESS-001 | Full staging regression pending. |
| Capacity must be established under normal, stress, spike and endurance load. | TC-PERF-001–TC-PERF-005 | Harness validated locally; formal staging result pending. |
| UAT must meet task, acceptance, SUS and critical-defect targets. | TC-UAT-001 | Protocol ready; human session pending. |
