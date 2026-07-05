# iRonda FYP Project Guideline

> Project: iRonda - Digital Patrol Operations Management for KRT/SRS
> Student: Mohamad Rafeeq Haiqal Bin Mazri, B032410536
> Institution: Universiti Teknikal Malaysia Melaka (UTeM), FTMK
> Last updated: 2026-07-04
> Status: Active FYP prototype development and submission preparation

---

## 1. Purpose of This Guideline

This document is the main working guideline for the iRonda Final Year Project. It explains how the project should be developed, tested, documented, and presented so the application, report, diagrams, database, and future changes stay aligned.

Use this guideline when:

- adding or changing application features;
- preparing the final report;
- updating diagrams, database design, or documentation;
- checking whether a proposed feature is inside the FYP scope;
- handing the project to another developer, supervisor, evaluator, or AI assistant.

This document should be read together with:

- `docs/CONTEXT.md` for deeper technical history and backlog details;
- `docs/DESIGN.md` for visual design rules;
- `docs/MILESTONE_PROGRESS.md` for completed and remaining work;
- `Report/iRonda_Final_Report_AI_Guideline.md` for final report writing direction.

---

## 2. Project Identity

### 2.1 Official Project Name

The system name used in the final report and presentation is **iRonda**.

### 2.2 Final Report Title

**iRonda: A Mobile Application for Digitizing Kawasan Rukun Tetangga (KRT) and Skim Rondaan Sukarela (SRS) Patrol Operations Management**

### 2.3 Project Positioning

iRonda is a **mobile application prototype** developed for a Final Year Project. It is designed to support KRT and SRS patrol operations by digitizing user approval, patrol scheduling, QR attendance, incident reporting, SOS alerts, equipment records, analytics, and Lampiran-style report generation.

The system must not be described as:

- an official nationwide JPNIN production system;
- a fully deployed government system;
- a real-time live tracking platform;
- an AI-based security system;
- a replacement for police or emergency response services.

Correct positioning:

> iRonda is a Flutter-based prototype supported by a PHP and MySQL/MariaDB backend to help digitize selected KRT/SRS patrol management activities.

---

## 3. Target Users and Role Names

### 3.1 Code-Level Roles

These role values are used in the application and database:

| Code role         | Meaning              |
| ----------------- | -------------------- |
| `peronda`       | SRS patroller        |
| `ketua_peronda` | Patrol leader        |
| `ketua_krt`     | KRT administrator    |
| `super_admin`   | System administrator |

### 3.2 Report-Level Role Names

Use these names in the final report:

| Code role         | Report term       |
| ----------------- | ----------------- |
| `peronda`       | SRS Patroller     |
| `ketua_peronda` | Patrol Leader     |
| `ketua_krt`     | KRT Administrator |
| `super_admin`   | Administrator     |

Avoid using "Super Admin" in the report. Use "Administrator" instead.

### 3.3 Main User Responsibilities

| Role              | Main responsibilities                                                                                                    |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------ |
| SRS Patroller     | Register account, view schedule, clock in/out using QR, submit incidents, trigger SOS, view own records                  |
| Patrol Leader     | Support assigned patrol squad, monitor shift activity, receive SOS awareness, assist patrollers                          |
| KRT Administrator | Approve accounts, manage members, squads, schedules, attendance, incidents, equipment, and reports within assigned scope |
| Administrator     | Manage wider state/district/zone scope, locations, users, reports, and system-level data                                 |

---

## 4. FYP Scope

### 4.1 Current Implemented or Intended Core Scope

The project scope should focus on these core functions:

1. User registration and login
2. Account approval and role-based access control
3. State, district, and zone organization
4. Squad and patrol schedule management
5. QR-based attendance clock-in and clock-out
6. GPS/location record for attendance and incident reporting
7. Incident reporting with image upload
8. Incident status viewing and updating
9. SOS emergency alert
10. Equipment inventory and return record
11. Dashboard analytics and hotspot summaries
12. Lampiran-style PDF/report generation
13. Bilingual interface support
14. Basic notification support

### 4.2 Out-of-Scope or Future Work

Do not present these as completed implementation unless they are actually built and tested:

- AI face blurring or image classification
- WebRTC or push-to-talk walkie-talkie
- production-grade real-time live tracking
- official JPNIN deployment
- Firebase Cloud Messaging as a completed production notification service
- hardware SOS button
- Google Maps API as an implemented map integration
- nationwide operational rollout

These items may be mentioned as future work only.

### 4.3 Scope Discipline

When adding features, ask:

1. Does this support the FYP objectives?
2. Does it help KRT/SRS patrol operation management?
3. Can it be completed, tested, and explained before submission?
4. Will it create report claims that are hard to prove?
5. Does it require official data or permissions that the project does not have?

If the answer creates risk, keep the feature as future work.

---

## 5. Project Objectives

Use these objectives consistently in report and presentation work:

1. To analyse the current problems in manual KRT and SRS patrol operations.
2. To design and develop iRonda, a mobile application for QR attendance, incident reporting, SOS emergency alerts, patrol schedules, equipment records, and report generation.
3. To evaluate the functionality and usability of iRonda for SRS patrollers, Patrol Leaders, and KRT Administrators.

Do not change these objectives unless the supervisor approves the change.

---

## 6. Technology Stack

### 6.1 Frontend

| Area                   | Technology                             |
| ---------------------- | -------------------------------------- |
| Framework              | Flutter / Dart                         |
| State management       | Provider / ChangeNotifier              |
| HTTP                   | `http` package                       |
| Local storage          | SharedPreferences                      |
| QR scanning            | mobile_scanner                         |
| QR generation          | qr_flutter                             |
| Location               | geolocator, geocoding                  |
| Image/camera           | camera, image_picker                   |
| Charts                 | fl_chart                               |
| PDF/report             | pdf, printing                          |
| Notification/vibration | flutter_local_notifications, vibration |
| Localization           | intl, flutter_localizations            |
| Logging                | logger                                 |

### 6.2 Backend

| Area             | Technology                   |
| ---------------- | ---------------------------- |
| Language         | PHP 8                        |
| Style            | Procedural PHP, no framework |
| Server           | XAMPP Apache                 |
| Database         | MySQL/MariaDB                |
| Database name    | `srs_db`                   |
| Database API     | MySQLi                       |
| Authentication   | JWT, HS256                   |
| Password hashing | `password_hash()` / bcrypt |
| File storage     | local`uploads/` directory  |

### 6.3 Development Tools

Use these tools consistently:

- Visual Studio Code
- Flutter SDK and Dart SDK
- Android Studio or physical Android device for testing
- XAMPP, Apache, MySQL/MariaDB, phpMyAdmin
- MySQL Workbench for database design and backup checks
- Git/GitHub for version tracking
- DigitalOcean only as deployment preparation unless actual deployment is completed and verified

---

## 7. Repository and Folder Guidelines

### 7.1 Main Paths

| Path                         | Purpose                                                            |
| ---------------------------- | ------------------------------------------------------------------ |
| `srs_app/`                 | Flutter application                                                |
| `srs_app/lib/`             | Flutter source code                                                |
| `srs_app/docs/`            | technical documentation                                            |
| `Report/`                  | FYP report assets, diagrams, drafts, and report guidance           |
| `db_backups/`              | database backups and migration snapshots                           |
| `Image generate/`          | generated UI images, profile images, incident samples, and mockups |
| `c:/xampp/htdocs/srs_api/` | local PHP backend API location                                     |

### 7.2 Documentation Files

| File                                           | Purpose                                                                   |
| ---------------------------------------------- | ------------------------------------------------------------------------- |
| `docs/PROJECT_GUIDELINE.md`                  | main working guideline                                                    |
| `docs/CONTEXT.md`                            | detailed project context, architecture, backlog, and implementation notes |
| `docs/DESIGN.md`                             | design tokens and visual rules                                            |
| `docs/MILESTONE_PROGRESS.md`                 | completed work and remaining milestones                                   |
| `docs/SUPER_ADMIN_TEST_REPORT.md`            | super-admin implementation and verification notes                         |
| `Report/iRonda_Final_Report_AI_Guideline.md` | report writing guideline                                                  |

---

## 8. Flutter Development Rules

### 8.1 Architecture

Follow the feature-first structure:

```text
lib/
  main.dart
  core/
    constants/
    network/
    providers/
    services/
    utils/
    widgets/
  features/
    auth/
    attendance/
    dashboard/
    incident/
    notifications/
    post/
    settings/
    tracking/
```

Rules:

- Keep shared utilities in `core/`.
- Keep feature-specific models, providers, services, and views inside `features/<feature>/`.
- Do not create random top-level files inside `lib/`; only `main.dart` should live there.
- Avoid importing one feature directly into another unless the current structure already requires it.
- Prefer passing data through providers, services, or shared core helpers.

### 8.2 State Management

Use Provider and ChangeNotifier only.

Do not introduce:

- Riverpod
- BLoC
- GetX
- Redux
- MobX

Each provider should:

- keep state small and purposeful;
- expose clear loading/error/success state where needed;
- call `notifyListeners()` only after meaningful state changes;
- avoid storing raw UI widget state that belongs inside the screen.

### 8.3 Network Calls

Use `ApiConstants` and `ApiClient` where possible.

Rules:

- Do not hardcode API URLs inside screens.
- Do not duplicate endpoint strings when a constant is available.
- Keep API parsing inside services/providers, not inside UI widgets unless the existing pattern makes it unavoidable.
- Always handle loading, empty, error, and success states.
- Ensure JWT token is included for protected endpoints.

### 8.4 Logging

Use the project logger.

Do not use:

- `print()`
- unnecessary `debugPrint()`
- noisy temporary logs left in production code

Logs should help identify network, parsing, authentication, or database issues without leaking passwords, IC numbers, or tokens.

### 8.5 Localization

Every user-facing string must support Malay and English where the screen is localized.

Rules:

- Add new strings to `SettingsProvider`.
- Check both `ms` and `en` entries.
- Avoid mixing translated and untranslated labels in the same screen.
- Keep role names consistent with the current UI language.

---

## 9. PHP Backend Guidelines

### 9.1 Backend Style

The backend uses raw procedural PHP. Keep it simple and consistent.

Rules:

- Do not add Laravel, Symfony, Slim, Node.js, or another backend framework.
- Use MySQLi consistently.
- Do not mix PDO methods with MySQLi connections.
- Keep one endpoint focused on one clear responsibility where possible.
- Keep shared connection/auth logic in `config/`.

### 9.2 API Response Format

Use this response shape:

```json
{
  "status": "success",
  "message": "Operation completed.",
  "data": {}
}
```

For errors:

```json
{
  "status": "error",
  "message": "Readable error message."
}
```

Rules:

- Do not use mixed response keys like `success: true` in new endpoints.
- Always return JSON.
- Set appropriate HTTP status codes where practical.
- Keep error messages useful but not overly technical for users.

### 9.3 Authentication and Authorization

Rules:

- Login and registration may be public.
- Protected endpoints must verify JWT.
- Extract `user_id` from the JWT token.
- Do not trust client-sent `user_id` for protected actions.
- Check role permissions server-side, not only in Flutter.
- Enforce location scope for KRT Administrator and Administrator reports.

### 9.4 SQL and Database Access

Rules:

- Use prepared statements for all user input.
- Validate required fields before database queries.
- Never concatenate user input directly into SQL.
- Close statements/connections where appropriate.
- Keep SQL readable and aligned with the current schema.

### 9.5 File Uploads

Rules:

- Store files under `uploads/`.
- Prefer storing relative paths in the database.
- Build full URLs in API responses or Flutter helpers.
- Validate file type and size.
- Delete related uploaded images when deleting incidents where the endpoint supports it.

---

## 10. Database Guidelines

### 10.1 Main Tables

The main database entities include:

- `users`
- `states`
- `districts`
- `zones`
- `squads`
- `squad_members`
- `schedules`
- `attendance`
- `incidents`
- `equipment_inventory`
- `equipment_logs`
- `notifications`

### 10.2 Data Design Rules

- Use UUIDs for new entities where the current table design expects UUID values.
- Preserve role values exactly: `peronda`, `ketua_peronda`, `ketua_krt`, `super_admin`.
- Preserve status values exactly as used by the system.
- Keep state, district, and zone relationships normalized.
- Avoid storing duplicated location text when IDs can be used.
- Avoid storing absolute IP-based image URLs.

### 10.3 Migration and Backup Workflow

Before applying a database change:

1. Export a full backup of `srs_db`.
2. Save the backup in `db_backups/` or `local_backups/` with a clear date.
3. Write or store the migration SQL clearly.
4. Apply the migration locally.
5. Verify table structure and sample data.
6. Run affected API smoke tests.
7. Update documentation with the migration name and purpose.

Never make schema changes without a backup.

---

## 11. UI and UX Guidelines

### 11.1 Design Personality

iRonda should feel:

- official;
- trustworthy;
- readable;
- calm;
- practical for patrol use;
- accessible for users of different ages.

The interface should not feel like a marketing landing page, game UI, or overly decorative dashboard.

### 11.2 Visual Rules

Follow `docs/DESIGN.md`.

Core rules:

- Use strong contrast for low-light patrol conditions.
- Use readable font sizes.
- Keep tap targets at least 48x48 logical pixels where possible.
- Avoid dense nested cards.
- Avoid hardcoded colors in widgets.
- Use `Theme.of(context).colorScheme`.
- Prefer Material 3 widgets.
- Keep admin dashboards structured for scanning, not decoration.

### 11.3 Screen Behavior

Every major screen should handle:

- loading state;
- empty state;
- error state;
- success state;
- offline or failed network state where relevant;
- permission-denied state for restricted roles.

### 11.4 Mobile and Responsive Testing

Test important screens on:

- physical Android phone;
- Chrome/web view where admin dashboards are wider;
- small mobile width;
- larger desktop/tablet width if the screen supports it.

Check for:

- overflow text;
- clipped buttons;
- bottom navigation overlap with system navigation;
- modal height issues;
- readable labels in Malay and English;
- broken image loading.

---

## 12. Security and Privacy Guidelines

### 12.1 Authentication

- Passwords must be hashed using bcrypt.
- JWT tokens must not be logged.
- Protected APIs must verify tokens.
- Role and location scope must be enforced on the backend.

### 12.2 Personal Data

The project may store personal data such as name, IC number, phone number, email, role, location, attendance, and incident records.

Rules:

- Do not expose sensitive fields unnecessarily.
- Do not log passwords, tokens, or full personal data.
- Use realistic demo data, not private real citizen data unless permission exists.
- Keep report claims honest about data source limitations.

### 12.3 Incident Images

Incident images are part of patrol records.

Rules:

- Use generated/demo images for testing and presentation where possible.
- Do not include private images in public report exports.
- Keep image storage paths consistent.

---

## 13. Testing and Verification Guidelines

### 13.1 Minimum Test Types

Each completed feature should be checked using:

- Flutter static analysis: `flutter analyze`
- manual UI walkthrough
- API smoke test for changed endpoints
- database verification if schema or data changed
- role-based test for each affected role
- mobile layout check

### 13.2 Role-Based Test Checklist

For feature changes, verify affected behavior for:

- SRS Patroller
- Patrol Leader
- KRT Administrator
- Administrator

If a role should not access a feature, test that it cannot access it from both:

- Flutter UI;
- backend API.

### 13.3 Feature Definition of Done

A feature is done only when:

1. UI is implemented and readable.
2. Backend endpoint works.
3. Database data is saved or fetched correctly.
4. Role permission is correct.
5. Loading, empty, and error states are handled.
6. Malay and English strings are added.
7. Flutter analysis passes.
8. Manual test result is recorded.
9. Documentation is updated if behavior changed.

---

## 14. Report and Documentation Guidelines

### 14.1 Report Writing Tone

Use simple academic English.

Preferred style:

- clear and direct;
- student-level;
- accurate to the actual prototype;
- no exaggerated claims;
- use tables for requirements and data dictionaries;
- use diagrams where they explain the system better than long paragraphs.

Avoid:

- saying the project "fully solves" all SRS problems;
- claiming official JPNIN adoption;
- claiming AI, live tracking, or push-to-talk is implemented;
- inventing survey results;
- using highly promotional wording.

### 14.2 Required Alignment

The report must align with:

- actual Flutter app features;
- PHP/MySQL backend architecture;
- current database schema;
- available screenshots and diagrams;
- FYP objectives;
- known limitations.

### 14.3 Diagram Rules

Use existing diagrams where possible:

- current manual SRS patrol operation flow;
- proposed iRonda patrol operation flow;
- use case diagrams by role;
- activity diagrams for QR attendance and incident/SOS reporting;
- system architecture;
- ERD/EERD/database design;
- sequence diagrams where needed.

Captions should be consistent:

- Figure 3.3: Use Case Diagram for SRS Patroller
- Table 3.1: Functional Requirements of iRonda

Use "iRonda" consistently, not "SRS Patrol System" in the final report unless explaining the domain.

---

## 15. Change Management Guidelines

### 15.1 Before Starting a Change

Before editing code, identify:

- feature or bug name;
- affected screens;
- affected API endpoints;
- affected database tables;
- affected roles;
- test plan.

### 15.2 During Development

Rules:

- Keep changes small and traceable.
- Do not refactor unrelated files.
- Preserve working behavior unless the change intentionally replaces it.
- Update translations while adding UI.
- Update API constants when adding endpoints.
- Keep database scripts and backups organized.

### 15.3 After Development

Record:

- changed files;
- migration or backup used;
- tests performed;
- known limitations;
- next follow-up task.

Use `docs/MILESTONE_PROGRESS.md` or a new feature test report when the change is large.

---

## 16. Current Priority Direction

Based on the current project state, prioritize work in this order:

1. Stabilize existing implemented features for demo and report alignment.
2. Fix hardcoded base URL / environment configuration issues.
3. Ensure relative image path handling is consistent.
4. Complete manual walkthrough for all roles.
5. Finalize report Chapters 1 to 4 with screenshots, diagrams, and data dictionary.
6. Add only high-value remaining features if time allows.

Recommended feature priority after stabilization:

1. Scheduling/calendar and reminder improvement.
2. SOS map view using OpenStreetMap/flutter_map if time allows.
3. Lampiran 6/report UI polish.
4. Batch selection only if the demo already works reliably.

Do not risk the final submission by adding large new features late unless they are clearly necessary.

---

## 17. Final FYP Demo Checklist

Before presentation or submission, prepare this flow:

1. Register as SRS Patroller.
2. Approve account as KRT Administrator or Administrator.
3. Login using approved account.
4. Create or verify location, squad, and schedule.
5. Generate QR code for attendance.
6. Clock in using QR and GPS.
7. Submit incident with category, location, and image.
8. Trigger SOS alert and show recipient awareness.
9. Record equipment usage and return.
10. View dashboard analytics.
11. Generate or preview Lampiran-style report.
12. Show role-based access difference between Patroller, Patrol Leader, KRT Administrator, and Administrator.

Prepare backup screenshots in case live demo network or local server fails.

---

## 18. Submission Readiness Checklist

Before final submission:

- Flutter app builds or runs on the demo device.
- XAMPP Apache and MySQL start correctly.
- `srs_db` backup is available.
- Demo accounts are ready for every role.
- API base URL matches current network/server setup.
- Incident images load correctly.
- QR scan works on the demo device.
- PDF/report generation works.
- All final screenshots are saved.
- Diagrams match the implemented system.
- Report does not mention unimplemented features as completed.
- Known limitations are written honestly.
- Final report, source code, database backup, and demo materials are organized.

---

## 19. Golden Rules

1. Keep the project honest to what is implemented.
2. Protect the FYP scope from unnecessary complexity.
3. Prioritize working demo flows over extra features.
4. Keep UI readable for night patrol and older community users.
5. Enforce role and location permissions on the backend.
6. Back up the database before migrations.
7. Add Malay and English text for new UI.
8. Do not store private or sensitive demo data carelessly.
9. Update documentation when behavior changes.
10. Treat iRonda as a serious prototype, not a production government system.
