# Skim Rondaan Sukarela (SRS) Digital Patrol System — Milestone & Codebase Progress Report

> **Project**: Skim Rondaan Sukarela (SRS) Digital Patrol System
> **Milestone Date**: 2026-06-18
> **Author**: Rafeeq (B032410536) — FYP, Universiti Teknikal Malaysia Melaka (UTeM)
> **Status**: Completed Iteration 2: Bottom Navigation Bar Redesign & Squad Card Interactivity — Clean Compile & Warning-Free

This document provides a comprehensive log of codebase modifications, categorised into **Adjustments**, **Fixes**, and **Removals** across the Flutter client (`srs_app`) and raw PHP backend (`srs_api`). It also serves as a tracking reference for the remaining work (bugs, improvements, and new features).

---

## 2026-06-27 Update: Super Admin Location Report Scope

Implemented on branch `feature/super-admin-location-report`.

- Added location-aware Lampiran D3(C) filters and backend report scoping for `super_admin` and `ketua_krt`.
- Added super-admin member management actions for profile edit, role update including `ketua_krt`, location transfer, and password reset.
- Added forced password-change flow using `users.must_change_password`.
- Added super-admin-only location management UI and `admin/locations.php`.
- Added migration `srs_api/migrations/20260627_super_admin_location_report.sql`.
- Verification: DB backup/migration passed, live API smoke tests passed, PHP lint passed for changed PHP files, and `flutter analyze` passed.
- Remaining: emulator UI walkthrough and full patrol regression flows still need hands-on testing.

Full details: `docs/SUPER_ADMIN_TEST_REPORT.md`.

---

## 2026-06-27 Follow-up: Super Admin Mobile Navigation

Manual retesting found that the super-admin mobile FAB navbar did not appear after
adding the eighth admin tab, which hid Member Management and therefore blocked
super-admin password reset testing. `ResponsiveShell` now handles any non-SOS
admin tab count of five or more, keeping `Super Admin`, `Lokasi`, `Skuad`, and
`Ahli` visible while moving the middle tools into the FAB menu. Ketua KRT
analytics also now shows a visible district-scope banner.

Verification: `flutter analyze` passed.

---

## 1. Codebase Modifications Summary

### 📊 Metric Overview
* **Adjustments**: 12 Changes
* **Fixes**: 8 Changes
* **Removals**: 7 Files/Features Deleted
* **File Health**: Clean compile, 0 compiler warnings, 0 static analysis errors.

---

### 1.1 Adjustments (UI Enhancements, Styling & Features)

We refactored several screens to standardise typography, align spacing, and match the Material 3 (M3) design system.

1. **QR Generator Screen Redesign**  
   * **File(s)**: [qr_generator_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/post/views/qr_generator_screen.dart)
   * **Details**: Updated the page layout to follow strict M3 rules: bold high-contrast typography, custom letter spacing, and a modern countdown progress bar above the expiration timer. Replaced the regeneration button with a 56px high M3 `FilledButton.icon` with elevated shadows.

2. **Incident List Feed Layout**  
   * **File(s)**: [incident_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/incident/views/incident_screen.dart)
   * **Details**: Redesigned cards to feature a rounded, left-aligned thumbnail (75x96 logical px) with metadata aligned in the center, and action items (submit, delete) on the right. Added a left-aligned tab configuration using `tabAlignment: TabAlignment.start` and removed the default bottom divider line via `dividerColor: Colors.transparent`. Replaced the report incident button with a standard M3 "+" FAB.

3. **Admin Dashboard Spacing Alignment**  
   * **File(s)**: [analytics_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/post/views/analytics_screen.dart)
   * **Details**: Reformatted the top 3 KPI cards by removing the `SingleChildScrollView` wrapper and aligning them in a non-scrolling `Row` with `Expanded` containers separated by `8px` spacing to replicate the patroller dashboard spacing. Centered inner typography and scaled down font sizes to prevent text wrapping.

4. **Bilingual Localisation Enhancements**  
   * **File(s)**: [settings_provider.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/core/providers/settings_provider.dart)
   * **Details**: Added Malay (`ms`) and English (`en`) translations for all new layout items: Today/Archive tabs, bulk-select options, warning modals, and scan validation failure notices.

5. **Combined Category Chart Card**  
   * **File(s)**: [analytics_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/post/views/analytics_screen.dart)
   * **Details**: Consolidated the duplicate crime category Pie Chart and the progress bar breakdown list into a single Card. Added a `24x24` pixel icon toggle button at the top-right of the card to switch between views.

6. **Combined Hotspot comparison Card**  
   * **File(s)**: [analytics_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/post/views/analytics_screen.dart)
   * **Details**: Consolidated the duplicate hotspot zone Bar Chart comparison and the Ranked list of hotspots into a single Card with a `24x24` toggle button at the top-right.

7. **Custom Rectangular Toggle**  
   * **File(s)**: [analytics_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/post/views/analytics_screen.dart)
   * **Details**: Created a custom `_buildRectangularSegmentedToggle` showing a rectangular bordered container with `BorderRadius.circular(8)`, checkmark icons, and a width sized at exactly **85%** of the standard Material 3 segmented control. Replaced the Line Chart's native segmented toggle with this widget.

8. **Security-Enhanced Incident Fetching**  
   * **File(s)**: [fetch_incidents.php](file:///c:/xampp/htdocs/srs_api/incidents/fetch_incidents.php)
   * **Details**: Integrated JWT security and role verification directly inside the PHP script, restricting regular patrollers to viewing only their own reports, and adding a `zone` parameter.

9. **Incident Status API Endpoint**  
   * **File(s)**: [update_status.php](file:///c:/xampp/htdocs/srs_api/incidents/update_status.php)
   * **Details**: Added an API endpoint to allow authorised roles to update the state (`status`) of incident reports.

10. **Central FAB Bottom Navigation Bar**  
    * **File(s)**: [responsive_shell.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/core/widgets/responsive_shell.dart)
    * **Details**: Redesigned the main bottom navigation bar to features a central Floating Action Button (FAB) that opens a horizontal floating overlay menu containing secondary pages, resolving navigation bar spacing layout cramps on mobile.

11. **Squad Member List Dialog Interactivity**  
    * **File(s)**: [schedule_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/dashboard/views/schedule_screen.dart), [dashboard_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/dashboard/views/dashboard_screen.dart)
    * **Details**: Encapsulated the squad banner cards inside clickable `InkWell` triggers to present an interactive, scrollable list modal of the squad members (displaying full names, phone numbers, and role badges).

12. **OS Navigation Bar Safety Alignment**  
    * **File(s)**: [responsive_shell.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/core/widgets/responsive_shell.dart)
    * **Details**: Integrated safe area bottom padding via `MediaQuery.of(context).padding.bottom` to dynamically push up all custom bottom navigation controls and menu drawer overlays above the system keys.

---

### 1.2 Fixes (Bugs & Code Integrity)

We resolved several runtime bugs, warnings, and logical errors that caused incorrect data groupings or compiler alerts.

1. **Persistent QR Generator State**  
   * **File(s)**: [qr_generator_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/post/views/qr_generator_screen.dart)
   * **Details**: Stored active QR code details, generated coordinates, and countdown timers in static variables (`_savedQrData`, `_savedLocation`, `_savedTime`, `_hasBeenGenerated`). This prevents the QR code from regenerating or resetting when the admin switches tabs or navigates away. The QR code now only resets if it expires or the admin manually triggers a new generation.

2. **JPNIN Incident Category Group Mapping**  
   * **File(s)**: [analytics_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/post/views/analytics_screen.dart)
   * **Details**: Fixed the `_getCategoryGroup` method. It previously grouped all crime statistics into "Lain-lain" (Others) because it expected prefixless exact matches. It has been rewritten to check substring containment (e.g., `.contains('Jenayah Kekerasan')`), mapping the 24 JPNIN crime types correctly.

3. **Active Patrol Feed Duplication**  
   * **File(s)**: [get_active_shifts.php](file:///c:/xampp/htdocs/srs_api/admin/get_active_shifts.php)
   * **Details**: Resolved duplicate rows caused by joint squad relationships or concurrent un-closed entries by adding a local `$seen_patrollers` tracking array in the SQL cursor fetch loop.

4. **Expired QR Scan Dialog Translations**  
   * **File(s)**: [settings_provider.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/core/providers/settings_provider.dart)
   * **Details**: Standardised translations for scanning an expired QR code (e.g., `QR Expired` / `This QR code has expired...`).

5. **Flutter SDK Compatibility (`withOpacity` Warning)**  
   * **File(s)**: Multiple files in `lib/`
   * **Details**: Replaced deprecated `.withOpacity()` references with `.withValues(alpha: ...)` to align with Flutter 3.22+ standards and achieve a warning-free compile.

6. **Hardcoded Color Refactor**  
   * **File(s)**: [attendance_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/attendance/views/attendance_screen.dart), [analytics_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/post/views/analytics_screen.dart)
   * **Details**: Replaced hardcoded black/white/grey styling properties with Theme context values (e.g. `Theme.of(context).colorScheme.surface`) to ensure theme integrity.

7. **Redundant AppBar Cleanups**  
   * **File(s)**: [schedule_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/dashboard/views/schedule_screen.dart)
   * **Details**: Removed Scaffold's `appBar` property to eliminate secondary header bars from showing on top of the main shell header on mobile.

8. **Translation Map Duplicate Keys**  
   * **File(s)**: [settings_provider.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/core/providers/settings_provider.dart)
   * **Details**: Resolved equal key map warnings by splitting the overlapping `'Ahli'` string into `'Ahli'` (plural category/navigation header) and `'Ahli (Peranan)'` (singular squad member role).

---

### 1.3 Removals (Dead Code & Feature Descope)

To clean up the codebase and align with the FYP scope boundaries, we purged several redundant files, folders, and UI sections.

1. **Active Patrol list feed Card ("Rondaan Aktif Semasa")**  
   * **File(s)**: [analytics_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/post/views/analytics_screen.dart)
   * **Details**: Completely deleted the active patrol list feed section, user avatars list, and state fields (`_activeShifts`) to eliminate compiler warning traces.

2. **Walkie-Talkie (PTT Radio Screen)**  
   * **File(s)**: [radio_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/communication/views/radio_screen.dart)
   * **Details**: Deleted this screen. The Walkie-talkie PTT feature was descoped due to dependencies.

3. **Privacy Service Placeholder**  
   * **File(s)**: [privacy_service.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/incident/services/privacy_service.dart)
   * **Details**: Deleted this unneeded 47-byte placeholder file.

4. **Incident Addendum Features (Frontend & Backend)**  
   * **File(s)**: [addendum_report_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/incident/views/addendum_report_screen.dart), [addendum.php](file:///c:/xampp/htdocs/srs_api/incidents/addendum.php), [get_addendums.php](file:///c:/xampp/htdocs/srs_api/incidents/get_addendums.php)
   * **Details**: Completely deleted frontend screens, backend endpoints, and the `uploads/addendums/` directories as the addendum reporting feature is out of scope.

5. **Legacy Duplicate incident Endpoint**  
   * **File(s)**: `c:\xampp\htdocs\srs_api\get_incidents.php` (root level)
   * **Details**: Removed the root duplicate endpoint. The app now queries exclusively from [get_incidents.php](file:///c:/xampp/htdocs/srs_api/incidents/get_incidents.php) inside the domain subdirectory.

6. **Folder Features in Incident Feed**  
   * **File(s)**: [incident_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/incident/views/incident_screen.dart)
   * **Details**: Removed folder groupings, folder list representations, and creation modals to simplify the feed layout.

---

## 2. Project Timeline & Milestones

Below is the structured project development timeline, tracking completed milestones and targeting submission deadlines for the FYP project.

| Phase | Core Deliverables / Tasks | Target Period | Status |
| :--- | :--- | :--- | :--- |
| **Phase 1: Core Foundation** | Setup Flutter shell, core networking (`api_client.dart`), provider architecture, initial authentication flows, and raw PHP API backend. | Late April 2026 | **Completed** |
| **Phase 2: JPNIN Form Features** | Implement Attendance (Lampiran C1/C2), Incident Reporting (Lampiran C3), SOS Emergency Polling, and Crime/Hotspot Analytics Dashboards. | Mid-May 2026 | **Completed** |
| **Phase 3: Stabilization & Refactor (Iteration 1)** | Fix Critical/High Bugs (BUG-001 to BUG-006), security JWT hardening, drop redundant features, resolve color/theme/SDK compatibility warnings. | Early June 2026 | **Completed** |
| **Phase 4: Navigation & Interactivity (Iteration 2)** | Custom central FAB bottom navigation bar, dynamic padding for system gesture keys, clickable squad cards displaying full modal rosters. | June 18, 2026 | **Completed** (Current) |
| **Phase 5: Advanced Features & Backlog** | JPNIN Lampiran 6 Report Redesign, open calendar modals, local push notifications (10.4), and OpenStreetMap SOS locations (10.6). | Late June - Mid-July 2026 | *Scheduled* |
| **Phase 6: Admin Panel & Cleanup** | User registration approval panel (10.1), bulk selections (10.2), HTTP call standardization (BUG-009), dynamic Base URL environment settings (BUG-010). | Mid-July - Late July 2026 | *Scheduled* |
| **Phase 7: Testing, Documentation & Submission** | Comprehensive blackbox/whitebox testing, performance profiling, final FYP report compilation, video demo, and project submission. | Early August 2026 | *Scheduled* |

---

## 3. Roadmap: Remaining Work & Backlog

This checklist summarizes **"how far and how many things we need to do"** to finalize the project for submission.

### 🔴 Critical & High Priority Bugs (All Solved)
- [x] **BUG-001: Rewrite Equipment Inventory API**
- [x] **BUG-002: Resolve SOS Alert Endpoint**
- [x] **BUG-003: Replace DropdownButtonFormField**
- [x] **BUG-004: Tighten JWT Token Verification**
- [x] **BUG-005: Cascade Delete Incident Photos**
- [x] **BUG-006: Server Sync for Active Shifts**

---

### 🟡 Medium & Low Priority Bugs
- [ ] **BUG-009: Standardise HTTP Call Patterns**  
  * *File*: [api_client.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/core/network/api_client.dart)  
  * *Issue*: Inconsistent patterns (some services use `ApiClient.postData` with form encoding, while others send raw JSON string payloads or custom `MultipartRequest` calls). Standardize requests.
- [ ] **BUG-010: Base URL Environment Configurations**  
  * *File*: [api_constants.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/core/constants/api_constants.dart)  
  * *Issue*: Base URL is hardcoded to a static local IP (`http://10.131.77.105/srs_api/`), causing network errors when switching Wi-Fi networks.
- [ ] **BUG-011: Relative Stored Image Paths**  
  * *File*: [upload_incident.php](file:///c:/xampp/htdocs/srs_api/incidents/upload_incident.php)  
  * *Issue*: Storing full image URLs with hardcoded server IPs in the database makes links break when the server IP changes. Store relative paths and append the host URL dynamically during API responses.
- [ ] **BUG-015: Implement Forgot Password Flow**  
  * *File*: [login_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/auth/views/login_screen.dart)  
  * *Demo Mitigation*: The link now opens a translated account assistance dialog that tells users to contact Ketua KRT for password reset or account reactivation.
  * *Remaining*: Full OTP validation and password reset API flow is still future scope.
- [ ] **BUG-016: Enable Profile Editing**  
  * *File*: [profile_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/auth/views/profile_screen.dart)  
  * *Issue*: Profile page is read-only. Need to allow users to update their name, email, or phone number.
- [ ] **BUG-017: Clean Up Dark Theme Code**  
  * *File*: [main.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/main.dart)  
  * *Issue*: Dark theme code is dead but still present. Clean up the unused code to keep compile bundles small.

---

### 🚀 Planned Features to Implement

- [ ] **10.1 User Management Panel (Admin)**  
  * *Description*: Admins should be able to review `pending` registrants and Approve (set `active`), Reject (set `inactive`), Promote (e.g., `peronda` → `ketua_peronda`), or toggle account status.  
  * *Work*: Extend [admin_member_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/post/views/admin_member_screen.dart) (currently a stub) and create `admin/update_user.php`.
- [ ] **10.2 Batch/Multi-Select Selection**  
  * *Description*: Enable batch member assignment (multi-select checkboxes in a bottom sheet to add up to 20 patrollers at once) and batch PDF download for monthly summaries.
- [ ] **10.4 Patrol Scheduling with Calendar & Notifications**  
  * *Description*: Add an interactive calendar view modal for patrollers to view upcoming scheduled shifts, set push notifications/reminders for approaching shifts, and integrate device calendar additions.
- [ ] **10.5 JPNIN Lampiran 6 Report Redesign**  
  * *Description*: Redesign the monthly reports to display as card list items (ordered by zone and state) with a vertical preview modal. Hotspots should display by default when no filters are selected.
- [ ] **10.6 SOS Map Integration**  
  * *Description*: Rename `MapScreen` to `SosScreen` and integrate an inline OpenStreetMap (`flutter_map` package) widget to view the exact location of active SOS triggers.
- [ ] **10.7 Remove Dead Dependencies**  
  * *Description*: Clean up `pubspec.yaml` by removing unused imports (`flutter_webrtc`, `google_mlkit_face_detection`) to reduce build size. Remove `incidents/fetch_incidents.php` (dead file).

---

## 4. Recommended Next Steps

1. **Advance to Scheduling & Notification Phase (10.4)**  
   * Build the patroller calendar view modal and scheduling alerts.
2. **User Management Panel Integration**  
   * Extend `admin_member_screen.dart` with a verification toggle so admins can approve pending accounts.
