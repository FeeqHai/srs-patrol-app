# Skim Rondaan Sukarela (SRS) Digital Patrol System — Milestone & Codebase Progress Report

> **Project**: Skim Rondaan Sukarela (SRS) Digital Patrol System
> **Milestone Date**: 2026-06-17
> **Author**: Rafeeq (B032410536) — FYP, Universiti Teknikal Malaysia Melaka (UTeM)
> **Status**: Completed Iteration 1 Refactoring & Cleanups — Ready for Next Phases

This document provides a comprehensive log of codebase modifications, categorised into **Adjustments**, **Fixes**, and **Removals** across the Flutter client (`srs_app`) and raw PHP backend (`srs_api`). It also serves as a tracking reference for the remaining work (bugs, improvements, and new features).

---

## 1. Codebase Modifications Summary

### 📊 Metric Overview
* **Adjustments**: 9 Changes
* **Fixes**: 6 Changes
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

## 2. Roadmap: Remaining Work & Backlog

This checklist summarizes **"how far and how many things we need to do"** to finalize the project for submission.

### 🔴 Critical & High Priority Bugs
- [ ] **BUG-001: Rewrite Equipment Inventory API**  
  * *File*: [get_inventory.php](file:///c:/xampp/htdocs/srs_api/equipment/get_inventory.php)  
  * *Issue*: Code attempts to call PDO methods (`fetchAll`) on a `mysqli` connection, which will crash at runtime. Needs to be rewritten using `mysqli` prepared statements.
- [ ] **BUG-002: Resolve SOS Alert Endpoint**  
  * *File*: `srs_api/tracking/sos_alert.php`  
  * *Issue*: Referenced by the Flutter service but does not exist. Must create the endpoint or redirect SOS alerts to use the `incidents/upload_incident.php` file under the category `Kecemasan`.
- [ ] **BUG-003: Replace DropdownButtonFormField**  
  * *File*: [admin_squad_schedule_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/post/views/admin_squad_schedule_screen.dart)  
  * *Issue*: Uses a non-existent parameter `initialValue` which throws layout compile issues on newer SDK versions. Replace with M3 `DropdownMenu`.
- [ ] **BUG-004: Tighten JWT Token Verification**  
  * *File*: Multiple PHP API endpoints  
  * *Issue*: Several endpoints do not enforce JWT checks and trust the client-sent `user_id` parameter directly, which is a security risk. Add verification logic.
- [ ] **BUG-005: Cascade Delete Incident Photos**  
  * *File*: [delete_incident.php](file:///c:/xampp/htdocs/srs_api/incidents/delete_incident.php)  
  * *Issue*: Deleting an incident record leaves stale images on the server filesystem. Add an `unlink()` operation.
- [ ] **BUG-006: Server Sync for Active Shifts**  
  * *File*: [dashboard_screen.dart](file:///c:/Users/rafee/Documents/UTeM/FYP/srs_app/lib/features/dashboard/views/dashboard_screen.dart)  
  * *Issue*: Shift active flag is only stored in local SharedPreferences. If the app restarts, the local state is lost or becomes stale. Needs a query to sync shift status on launch.

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
  * *Issue*: The link exists on the UI but does nothing. Needs a forgot password API flow (OTP, validation, and reset).
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

## 3. Recommended Next Steps

1. **Equipments & SOS Core Fixes (High Priority)**  
   * Resolve `BUG-001` (mysqli syntax fix in [get_inventory.php](file:///c:/xampp/htdocs/srs_api/equipment/get_inventory.php)) and `BUG-002` (SOS routing) to ensure the core equipment inventory and SOS reception pipelines do not crash.
2. **User Management Panel Integration**  
   * Extend `admin_member_screen.dart` with a verification toggle so admins can approve pending accounts.
3. **Advance to Scheduling & Notification Phase (10.4)**  
   * Build the patroller calendar view modal and scheduling alerts.
