# iRonda UAT protocol and task sheet

Version 2 | Updated 8 September 2026 | Prepared for execution

Run practical tasks before participants complete the [Google Forms questionnaire](../../Report/Done/UAT/iRonda_Google_Forms_Questionnaire_v2.md). The linked file contains the full question wording, options and form setup instructions. The online form has not yet been created. Use [uat_result_record.md](uat_result_record.md) to collect observed outcomes. No responses or test results are asserted by this protocol.

## Participants and consent

The previous recruitment proposal comprised six patrollers, two leaders, two KRT administrators, one system administrator and one observer. This means 11 planned task participants plus one observer, not 12 completed questionnaire responses. It is not a faculty minimum. Finalise the achievable recruitment target, essential tasks and role coverage before collection and report the actual sample afterwards.

Recruit actual role holders where possible. Record representative testers honestly. Use anonymous codes such as UAT-001. Record actual background separately from the app role assigned during the session. A person is one respondent even if they try several roles. An observer only counts as a participant if they personally perform tasks and answer the questionnaire; otherwise keep them separate.

Explain voluntary participation and anonymous reporting. Record consent before testing and stop when consent is No. Use no participant names, emails, identity numbers or identifiable photos in the questionnaire or evidence dataset. Use synthetic test identities and records. Do not ask participants to capture their real MyKad. Do not publish identifying quotations or revealing small-group breakdowns.

## Environment and preparation

Record session ID, evaluation round, date, facilitator ID, app build or source revision, API revision, database baseline, device model, Android version, app language, network and actual API environment. Test with isolated records and accounts. For online evaluation use an isolated HTTPS test deployment; if testing locally, label the results local XAMPP HTTP and do not claim online acceptance. Check the selected environment explicitly because launch profiles do not synchronise servers or databases.

Prepare four-role test accounts, locations, squads, equipment and a suitable schedule for the test date. Use physical Android devices for camera, QR and location activities. Coordinate leader and member accounts so connected tasks can be observed. Prepare the permitted patrol location and required permissions. Verify that a synthetic MyKad fixture works with the actual OCR capture flow before the session. If it cannot, record the registration task as Blocked instead of bypassing the checks or claiming a demonstration as a completed task.

Current registration uses on-device MyKad text recognition, with no selfie, face matching or liveness step. After verification, name and IC are locked; the applicant selects operating state, district and zone. A valid verified session is required to submit the pending application.

SOS tests must use isolated sender and receiver accounts with the facilitator and receivers aware of the exercise. Keep the receiver view active for polling and record observed delay. The active workflow has no continuous live location tracking or promise of an immediate response. Do not send operational emergency alerts during UAT.

## Procedure

1. Obtain consent, assign the participant code and record actual background and the main assigned role.
2. Select applicable tasks before execution. Give a brief consistent orientation without demonstrating each solution. Record any additional help.
3. Observe first attempts and record task time, outcome, assistance and issues. Keep retest attempts separate. Prepare prerequisites or coordinate participants in workflow order.
4. Ask participants to complete the Google Form independently after their tasks. Do not coach ratings. Record any translation or additional explanation.
5. Preserve original responses and outcomes. Record subsequent fixes and retests as a separate round when the build or instrument changes materially.

## Task catalogue

P = SRS Patroller; L = Patrol Leader; K = KRT Administrator; S = Super Administrator. Assign only actions available to the tested role in the current app. Each participant completes the common tasks and the relevant role tasks, not every module.

| Task | Role | Instruction | Observable completion evidence |
|---|---|---|---|
| T01 | New applicant | Capture the supplied synthetic MyKad. | Verified registration form shows locked test name and IC. |
| T02 | New applicant | Select operating state, district and zone, enter supplied account details and submit. | Pending application is created and the outcome is understandable. |
| T03 | K or S | Find and approve the pending test applicant within authorised scope. | Account status becomes active and the applicant can subsequently log in. |
| T04 | P, L, K, S | Log in and locate the main functions for the assigned role. | Correct role home appears and requested function is located. |
| T05 | K or S | Prepare the supplied squad membership and patrol schedule. | Intended members, patrol location, date and time are saved and reviewable. |
| T06 | P or L | Find the assigned patrol schedule. | Participant identifies the correct date, time and location. |
| T07 | L | Start today's prepared shift and display the attendance QR. | Active shift and relevant IN code appear. Use one suitable schedule; do not assume free schedule selection. |
| T08 | P | Scan the leader's current IN code at the permitted location. | Member attendance becomes active and the participant recognises check-in success. |
| T09 | P or L | Record the supplied equipment using the available issue action. | Intended item and quantity appear in the relevant record. Assign only where the tested role view supports the action. |
| T10 | P or L | Create and submit a synthetic daily note or incident, optionally with a safe test photo. | Participant finds the record and recognises its status. |
| T11 | P | Trigger the supervised SOS test. | Submission outcome and corresponding synthetic incident are recorded. |
| T12 | L, K or S | Receive and acknowledge the test SOS within authorised scope. | Intended receiver finds and acknowledges the alert. Record actual receipt delay. |
| T13 | P | Scan the current OUT code and complete the displayed return inputs. | Member return becomes pending acknowledgement, not yet completed attendance. |
| T14 | L, K or S | Review and acknowledge the member's normal equipment return. | Member attendance completes after the authorised acknowledgement. |
| T15 | L | Record the supplied attendance assessment, then end the leader's own shift. | Assessment is saved and leader attendance completes through the direct end-shift action. |
| T16 | K or S | Review attendance and generate the available attendance book or Monthly D3(C) PDF. | Participant finds the relevant period/records in the requested report. Record the exact report tested. |
| T17 | P, L, K, S | Review profile, change a permitted test field, open notifications and change app language. | Permitted change persists and requested views/language are found. Exclude font size and high contrast, which remain Coming soon. |
| T18 | K or S | Find a supplied inventory item and update its permitted test quantity. | Revised quantity is visible. Do not assume geographically separated inventory. |
| T19 | S | Locate the supplied administrative location and user records. | Participant locates the requested records in the available administration views. |

T04 and T17 are common tasks. Registration is only for participants assigned that workflow. A prepared account may support other tasks when registration is blocked, but retain that limitation. If observing several actions separately in T05, T15, T16 or T17, split into child IDs before the round; a combined task succeeds only when all assigned actions succeed. Never count an untested feature as passed because another action in its module succeeded.

## Outcome definitions

- Independent: the observable outcome is reached without task-specific help after orientation.
- Assisted: the outcome is reached with help; describe the assistance.
- Not completed: attempted but the outcome is not reached.
- Blocked: assigned and applicable but an app, environment or prerequisite problem prevents execution; give the reason.
- N/A: outside the agreed task scope or role; give the reason. Do not use N/A for a failure or technical block.

Record withdrawals separately from technical blocks. Disclose any incomplete sessions excluded from analysis. Use first attempts for the initial round's completion rate and report retests separately.

## Questionnaire and analysis

Use the linked Google Forms questionnaire as the single current source of item wording. Keep instrument wording and scales stable within a round. Prepare and check any Malay translation before use and record its version.

Section 3 has ten custom acceptance items A01 to A10. Responses are 1 to 5 plus N/A. Missing and N/A are not zero or Neutral. Show valid, missing and N/A counts per item. For this protocol, calculate a participant mean only with at least eight valid A answers, then average eligible participant means. Report the eligible sample. This completeness rule is a project choice fixed before collection.

Section 4 retains all ten System Usability Scale items S01 to S10, each answered 1 to 5. For complete responses, odd-item contribution = response minus 1; even-item contribution = 5 minus response; sum contributions and multiply by 2.5. Calculate SUS only when all ten answers are present and valid. Report the mean of complete participant scores and the incomplete count. SUS is a score on a 0 to 100 scale, not a percentage. Do not combine it with acceptance or feature questions.

Section 5 has four feature questions F01 to F04, with 1 to 5 plus N/A. Analyse their distributions separately. Section 6 has four optional comments O01 to O04. Group comments by theme and retain contradictory or negative feedback as well as positive feedback.

Applicable task denominator = Independent + Assisted + Not completed + Blocked for assigned first attempts in the reported round. Combined completion = (Independent + Assisted) / denominator × 100. Independent completion = Independent / denominator × 100. Show both rates and count justified N/A separately. Keep these results separate from the report's 75 developer test cases.

## Acceptance decision and report

Retain the previous draft's targets as project targets, not faculty requirements: at least 90% combined task completion; eligible acceptance mean at least 4.0/5; complete-response SUS mean at least 68; and no unresolved critical defect in the evaluated scope.

Before testing, identify essential roles/workflows and define defect severity. A critical defect prevents an essential task without a practical workaround or causes serious data loss or unauthorised disclosure. Report actual recruitment and task coverage against the plan. If an essential workflow or role is untested, evidence is incomplete or a required score cannot be calculated, use Incomplete for the intended scope. Averages alone cannot establish acceptance. Any acceptance statement applies only to the tested build, environment, sample and tasks; it is not proof of general production readiness.

Use actual responses for Chapter 6 participant charts, task results, acceptance distributions, SUS summary and feedback/actions. Label actual background separately from assigned role. Include the instrument and anonymised evidence in Appendix B and update Chapter 7 from the observed results.
