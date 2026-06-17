# SRS Patrol System — Comprehensive Project Guidelines (CONTEXT.md)

> **Project**: Skim Rondaan Sukarela (SRS) Digital Patrol System
> **Author**: Rafeeq (B032410536) — FYP, Universiti Teknikal Malaysia Melaka (UTeM)
> **Last Updated**: 2026-06-17
> **Status**: Active Development — FYP Submission Phase

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Tech Stack](#2-tech-stack)
3. [Architecture](#3-architecture)
4. [Database Schema](#4-database-schema)
5. [API Reference](#5-api-reference)
6. [Feature Catalog](#6-feature-catalog)
7. [Design System](#7-design-system)
8. [Coding Conventions](#8-coding-conventions)
9. [Known Bugs & Issues](#9-known-bugs--issues)
10. [Planned Features](#10-planned-features)
11. [Skills & References](#11-skills--references)
12. [Do's and Don'ts](#12-dos-and-donts)
13. [Development Environment](#13-development-environment)

---

## 1. Project Overview

The SRS Patrol System is a **multi-platform digital solution** that modernizes Rukun Tetangga (KRT) volunteer neighbourhood patrols in Malaysia. It digitizes attendance tracking, incident reporting, SOS emergencies, squad/schedule management, equipment tracking, and crime analytics — replacing the paper-based LAMPIRAN SRS C1–C3 forms mandated by JPNIN RT 01 SOP.

### 1.1 Domain Terminology

| Malay Term | English | Context |
|---|---|---|
| Skim Rondaan Sukarela (SRS) | Voluntary Patrol Scheme | The national program |
| Rukun Tetangga (KRT) | Neighbourhood Watch | Community organization |
| Peronda | Patroller | Volunteer field patrol member |
| Ketua Peronda | Squad Leader / Head Patroller | Assigned per shift, gives briefings |
| Ketua KRT | KRT Admin / Chairman | Command center, manages everything |
| Pusat Rondaan | Patrol Center / Command Post | Physical base of operations |
| Syif | Shift | A patrol session with assigned team |
| LAMPIRAN SRS C1 | Attendance Record Book | Official attendance form |
| LAMPIRAN SRS C2 | Equipment Distribution Log | Official equipment form |
| LAMPIRAN SRS C3 | Daily Findings Notebook | Official incident logbook |
| Lampiran 4 | Formal Daily Patrol Notes | PDF export from app |
| Lampiran 6 | Monthly Incident Summary | PDF export — JPNIN D3(C) form by category, zone, state |
| JPNIN | National Community Dept. | Government body overseeing KRT |
| Buku Nota Harian | Daily Notebook | Patroller's daily written notes |
| Jenayah Kekerasan | Violent Crime | Incident category group A |
| Jenayah Harta Benda | Property Crime | Incident category group B |

### 1.2 JPNIN Incident Categories (24 Standard Categories)

The system uses the official JPNIN incident classification with hierarchical grouping:

| Group | Categories |
|---|---|
| **A. Jenayah Kekerasan** | Bunuh, Rogol, Samun Berkawan Bersenjata Api, Samun Berkawan Tanpa Senjata Api, Samun Seorang Bersenjata Api, Samun Seorang Tanpa Senjata Api |
| **B. Jenayah Harta Benda** | Pecah Rumah Siang, Pecah Rumah Malam, Curi Kenderaan (Motosikal), Curi Kenderaan (Kereta/Lain), Curi Ragut, Curi Am |
| **C. Jenayah Lain** | Dadah, Judi, Peras Ugut, Along, Vandalism, Gangguan Seksual, Cetak Rompak, Penipuan Siber/Dalam Talian |
| **D. Lain-lain** | Kebakaran, Banjir, Kemalangan Jalan Raya, Kecemasan (SOS) |

### 1.3 "Reported To" Agencies

| Agency | Context |
|---|---|
| Polis (PDRM) | For criminal incidents |
| Jabatan Agama | For religious matters |
| PBT (Pihak Berkuasa Tempatan) | Local authority for civil issues |
| JKM (Jabatan Kebajikan Masyarakat) | Social welfare dept. |
| Tiada | No report made |

---

## 2. Tech Stack

### 2.1 Frontend — Flutter Mobile & Web App

| Component | Technology | Version |
|---|---|---|
| Framework | Flutter / Dart | SDK `^3.11.0` |
| State Management | `provider` | `^6.1.1` |
| HTTP Client | `http` | `^1.2.0` |
| Session Storage | `shared_preferences` | `^2.5.5` |
| QR Scanning | `mobile_scanner` | `^7.2.0` |
| QR Generation | `qr_flutter` | `^4.1.0` |
| GPS / Location | `geolocator` | `^14.0.2` |
| Geocoding | `geocoding` | `^4.0.0` |
| Charts | `fl_chart` | `^1.2.0` |
| Camera | `camera` | `^0.11.0` |
| Image Picking | `image_picker` | `^1.2.2` |
| PDF Generation | `pdf` | `^3.11.3` |
| PDF Printing | `printing` | `^5.14.2` |
| Notifications | `flutter_local_notifications` | `^22.0.0` |
| Vibration | `vibration` | `^2.0.0` |
| URL Launcher | `url_launcher` | `^6.3.2` |
| Date Range Picker | `calendar_date_picker2` | `^3.0.0` |
| UUID Generation | `uuid` | `^4.5.3` |
| Logging | `logger` | `^2.7.0` |
| Internationalisation | `intl` | `^0.20.2` |
| Localisation | `flutter_localizations` | SDK |
| Linting | `flutter_lints` | `^6.0.0` |
| App Icon | `flutter_launcher_icons` | `^0.14.4` |
| Maps | `flutter_map` | *To be added* — for SOS location viewing (OpenStreetMap) |

**Removed Dependencies** (not in FYP scope):
- ~~`flutter_webrtc: ^0.12.2`~~ — Walkie-talkie PTT removed from scope
- ~~`google_mlkit_face_detection: ^0.12.0`~~ — PDPA face blurring removed from scope

### 2.2 Backend — Raw PHP API

| Component | Technology |
|---|---|
| Language | PHP 8 (procedural, **no framework**) |
| Server | XAMPP (Apache + MariaDB 10.4.32) |
| Database | MySQL/MariaDB → `srs_db` (charset `utf8mb4`) |
| Auth | JWT (HS256, 7-day expiry) via `config/jwt_utils.php` |
| Password Hashing | `password_hash()` with `PASSWORD_BCRYPT` |
| CORS | Wildcard (`Access-Control-Allow-Origin: *`) |
| File Storage | Local `uploads/` directory (incident images) |

---

## 3. Architecture

### 3.1 Flutter App — Feature-First Modular Structure

```
lib/
├── main.dart                          # App entry, MultiProvider, theming, RootRouter
│
├── core/                              # ── SHARED INFRASTRUCTURE ──
│   ├── constants/
│   │   └── api_constants.dart         # Base URL + endpoint path constants
│   ├── network/
│   │   └── api_client.dart            # Static HTTP GET/POST wrapper (centralised)
│   ├── providers/
│   │   └── settings_provider.dart     # Locale (ms/en), ~200+ translation entries
│   ├── services/
│   │   └── sos_alert_service.dart     # SOS polling singleton (10s interval)
│   ├── utils/
│   │   └── logger.dart                # Logger wrapper instance (appLogger)
│   └── widgets/
│       ├── main_shell.dart            # Patroller bottom nav shell (3 tabs + SOS)
│       ├── responsive_shell.dart      # Responsive layout wrapper (breakpoint 800px)
│       ├── global_menu_button.dart    # Profile/Settings/Logout popup menu
│       └── image_viewer_screen.dart   # Full-screen PageView image gallery + pinch zoom
│
├── features/                          # ── FEATURE MODULES ──
│   ├── auth/
│   │   ├── models/
│   │   │   └── user_model.dart        # UserModel with fromJson/toJson
│   │   ├── providers/
│   │   │   └── auth_provider.dart     # Login/logout, session persistence (SharedPreferences)
│   │   ├── services/
│   │   │   └── auth_service.dart      # Registration API calls
│   │   └── views/
│   │       ├── login_screen.dart      # Email/password login (responsive split-screen)
│   │       ├── register_screen.dart   # New patroller registration (form + zone dropdown)
│   │       └── profile_screen.dart    # Read-only profile display
│   │
│   ├── incident/
│   │   ├── providers/
│   │   │   └── incident_provider.dart # Incident data fetching and state
│   │   ├── services/
│   │   │   ├── incident_service.dart  # Incident API calls (MultipartRequest for uploads)
│   │   │   └── privacy_service.dart   # PLACEHOLDER — 47 bytes, to be removed
│   │   └── views/
│   │       ├── incident_screen.dart           # Incident feed list with filtering
│   │       ├── incident_report_screen.dart    # Submit new incident (category picker, camera, GPS)
│   │       ├── incident_detail_screen.dart    # Full detail + PDF generation
│   │       └── lampiran_6_screen.dart         # JPNIN D3(C) monthly stats + PDF (867 lines)
│   │
│   ├── attendance/
│   │   ├── providers/
│   │   │   └── attendance_provider.dart  # QR scan processing, shift state
│   │   ├── services/
│   │   │   └── attendance_service.dart   # Clock-in/out API calls
│   │   └── views/
│   │       └── attendance_screen.dart    # QR scanner + equipment checkout (608 lines)
│   │
│   ├── tracking/
│   │   ├── providers/
│   │   │   └── tracking_provider.dart    # SOS trigger state
│   │   ├── services/
│   │   │   └── tracking_service.dart     # SOS alert API calls
│   │   └── views/
│   │       └── map_screen.dart           # SOS trigger button (to be replaced with flutter_map)
│   │
│   ├── post/                             # ── ADMIN & KETUA SCREENS ──
│   │   └── views/
│   │       ├── admin_shell.dart                    # Admin nav container (4 tabs)
│   │       ├── ketua_mobile_layout.dart             # Ketua nav container (4 tabs + SOS)
│   │       ├── analytics_screen.dart                # KPI cards + charts (514 lines)
│   │       ├── qr_generator_screen.dart             # Generate time-limited QR codes
│   │       ├── admin_incident_screen.dart            # Browse patrollers → view their incidents
│   │       ├── admin_member_screen.dart              # View all registered patrollers (STUB: no edit)
│   │       └── admin_squad_schedule_screen.dart      # Squad + Schedule CRUD (872 lines)
│   │
│   └── dashboard/
│       └── views/
│           └── dashboard_screen.dart    # Main landing: patrol status, SOS feed, 7-day chart (19KB)
```

**Structural Rules:**
- **DO** place new features under `features/<feature_name>/` with subdirectories: `models/`, `providers/`, `services/`, `views/`.
- **DO** place shared/cross-cutting code under `core/`.
- **DO NOT** create top-level files in `lib/` (only `main.dart` lives there).
- **DO NOT** import from one feature module into another. Features communicate through `core/` or providers at the app root.
- **EXCEPTION**: `post/views/` may reference `incident/views/` and `dashboard/views/` because admin screens compose patroller screens.

### 3.2 PHP API — Flat File-Per-Endpoint Structure

```
srs_api/
├── config/
│   ├── db_connect.php          # MySQLi connection + CORS headers (included by ALL endpoints)
│   └── jwt_utils.php           # JWT generate/verify/extract (HS256, 7-day expiry)
│
├── auth/
│   ├── login.php               # POST — email+password → JWT token + user data
│   ├── register.php            # POST — create user (default: pending status)
│   ├── get_profile.php         # GET  — user profile by ID
│   └── get_patrollers.php      # GET  — list peronda/ketua_peronda users
│
├── admin/
│   ├── squads.php              # GET/POST — multi-action CRUD (create/add/remove/delete squad)
│   ├── schedules.php           # GET/POST — multi-action CRUD (create/delete schedule)
│   ├── get_stats.php           # GET  — KPI metrics for analytics dashboard
│   └── get_active_shifts.php   # GET  — currently active patrol shifts
│
├── attendance/
│   ├── clock_in.php            # POST — QR validation + Haversine GPS check + equipment log
│   ├── clock_out.php           # POST — end shift, mark equipment returned
│   └── log_equipment.php       # POST — log equipment borrowing
│
├── equipment/
│   └── get_inventory.php       # GET  — equipment list with available quantities
│
├── incidents/
│   ├── upload_incident.php     # POST (multipart) — submit incident with images
│   ├── fetch_incidents.php     # GET  — filtered incident list (UNUSED by Flutter)
│   ├── get_incidents.php       # GET  — incident list (optional user_id filter)
│   ├── delete_incident.php     # POST — delete incident by ID
│   ├── check_sos.php           # GET  — poll for SOS alerts (30-minute window)
│   └── get_lampiran_6_summary.php  # GET — monthly JPNIN category × agency stats
│
├── uploads/                    # File storage directory
│   └── incidents/              # Incident report images
│
├── seed_users.php              # Dev utility — creates test users
├── create_dummy.php            # Dev utility — creates test users
└── get_incidents.php           # ROOT-LEVEL DUPLICATE — legacy, should be removed
```

**Structural Rules:**
- **DO** group endpoints by domain in subdirectories.
- **DO** include `config/db_connect.php` at the top of every endpoint.
- **DO** use multi-action endpoints via `$_POST['action']` for closely related CRUD operations on the same resource.
- **DO NOT** create framework-like abstractions (ORM, routers, base controller classes).
- **DO NOT** store uploaded files outside the `uploads/` directory.
- **MUST** enforce JWT authentication on ALL endpoints except `auth/login.php` and `auth/register.php`.

### 3.3 Role-Based Routing (RootRouter in `main.dart`)

```dart
Consumer<AuthProvider>(
  builder: (context, authProvider, child) {
    if (!authProvider.isAuthenticated) → LoginScreen
    if (role == 'ketua_krt' || role == 'ketua') → AdminShell     // Responsive web+mobile
    if (role == 'ketua_peronda') → KetuaMobileLayout              // Mobile only
    if (role == 'peronda') → MainShell                            // Mobile only
  }
)
```

| Role | Shell | Tabs | Platform | SOS Button |
|---|---|---|---|---|
| Not authenticated | `LoginScreen` | — | — | No |
| `peronda` | `MainShell` | Dashboard, Incidents, Attendance | Mobile | Yes (center FAB) |
| `ketua_peronda` | `KetuaMobileLayout` | Dashboard, Incidents, Admin Incident Reports, Attendance | Mobile | Yes (center FAB) |
| `ketua_krt` | `AdminShell` | Analytics, QR Generator, Incident Reports, Squads & Schedules | Web + Mobile | No |

### 3.4 State Management

Five `ChangeNotifierProvider`s registered at the app root via `MultiProvider` in `main.dart`:

| # | Provider | Purpose | Key State |
|---|---|---|---|
| 1 | `AuthProvider` | Login, logout, session persistence | `isAuthenticated`, `userId`, `role`, `fullName` |
| 2 | `IncidentProvider` | Incident data fetching and mutation | Incident list, loading/error states |
| 3 | `AttendanceProvider` | QR scan processing, shift state | Shift active flag, checkpoint ID, attendance records |
| 4 | `TrackingProvider` | SOS trigger state | GPS coordinates, SOS status |
| 5 | `SettingsProvider` | Locale, translations | Current locale (`ms`/`en`), `t(key)` method, ~200+ translation pairs |

**Rules:**
- **DO** use `ChangeNotifier` + `Provider`. Do NOT introduce Riverpod, BLoC, or GetX.
- **DO** register all providers in `main.dart`'s `MultiProvider`.
- **DO** use `context.read<T>()` for one-time access and `context.watch<T>()` or `Consumer<T>` for reactive rebuilds.
- Each feature's provider should delegate API calls to its corresponding service class.

### 3.5 Network Call Chain

```
View → Provider → Service → ApiClient → PHP Endpoint
```

- **`ApiClient.postData(endpoint, body)`** — sends form-encoded POST, returns decoded JSON `Map`.
- **`ApiClient.getData(endpoint)`** — sends GET, returns decoded JSON.
- **Exception**: `IncidentService` uses `http.MultipartRequest` directly for file uploads (bypasses `ApiClient`).
- **MUST FIX**: `TrackingService` sends JSON body via raw `http.post` — should use `ApiClient` or be consistent.

### 3.6 Authentication Flow (JWT-Enforced)

```
1. User submits email + password → LoginScreen
2. AuthProvider.login() → ApiClient.postData('auth/login.php', {...})
3. PHP: password_verify() + account_status check → generates JWT via generate_jwt()
4. Response: {"status": "success", "token": "<JWT>", "data": {id, full_name, role, ...}}
5. Flutter: caches JWT token, user_id, user_role in SharedPreferences
6. All subsequent API calls: send JWT in Authorization: Bearer <token> header
7. PHP endpoints: verify_jwt() → extract user_id from token payload
8. On logout: SharedPreferences cleared → RootRouter returns to LoginScreen
9. Forgot Password Flow(Implementation needed):
    a. User clicks "Forgot Password" on LoginScreen → navigate to `ForgotPasswordScreen`
    b. User enters email address
    c. App calls `auth/forgot_password.php` with email
    d. PHP generates 6-digit OTP, stores in DB, sends email via SendGrid API
    e. User enters OTP → app calls `auth/verify_otp.php` with email + OTP
    f. PHP validates OTP and returns token for password reset
    g. User enters new password → app calls `auth/reset_password.php` with email + OTP + new password
    h. Password updated → user redirected to LoginScreen
```

### 3.7 Localisation System

Custom in-app translation via `SettingsProvider`:
- Default locale: **`ms` (Bahasa Melayu)**
- Supported: `ms`, `en`
- Translation method: `settings.t('key_name')` returns localised string
- Translations stored as hardcoded `Map<String, Map<String, String>>` (~200+ entries)
- Locale persisted in `SharedPreferences` as `languageCode`
- **NOT using `.arb` files** or `intl` code generation

**Rule**: All new user-facing strings MUST have both `ms` and `en` entries added to `SettingsProvider`'s translation map.

---

## 4. Database Schema (`srs_db`)

### 4.1 Entity Relationship

```
users ─┬── 1:N ──→ incidents
       ├── 1:N ──→ attendance ──── 1:N ──→ equipment_logs
       └── M:N ──→ squad_members ──→ squads ──── 1:N ──→ schedules
                                      │                     ↑
                                      └── zone   attendance.schedule_id ──┘ (nullable FK)

equipment_inventory ←── equipment_logs.equipment_id

users.state / users.district / users.zone  ← Location hierarchy (see 4.4)
```

### 4.2 Table Definitions

#### `users`
| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | VARCHAR(36) | PK | UUID v4 |
| `full_name` | VARCHAR(255) | NOT NULL | |
| `ic_number` | VARCHAR(20) | UNIQUE, NOT NULL | Malaysian IC |
| `phone_number` | VARCHAR(20) | | |
| `email` | VARCHAR(255) | UNIQUE, NOT NULL | |
| `password_hash` | VARCHAR(255) | NOT NULL | bcrypt |
| `state` | VARCHAR(100) | NOT NULL, INDEX | Negeri — e.g., `Melaka` |
| `district` | VARCHAR(100) | NOT NULL, INDEX | Daerah — e.g., `Alor Gajah` |
| `zone` | VARCHAR(100) | NOT NULL, INDEX | Zon Rondaan — e.g., `Zon Pusat` |
| `role` | ENUM | NOT NULL | `peronda`, `ketua_peronda`, `ketua_krt` |
| `account_status` | ENUM | DEFAULT `pending` | `pending`, `active`, `inactive` |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |

> **Migration note**: The old `district_zone` column (e.g., `'Zon Pusat'`) is replaced by three separate columns: `state`, `district`, `zone`. See Section 4.4 for the location hierarchy.

#### `squads`
| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | VARCHAR(36) | PK (UUID) | |
| `name` | VARCHAR(255) | NOT NULL | |
| `zone` | VARCHAR(100) | DEFAULT NULL | Links squad to a specific patrol zone |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |

#### `squad_members`
| Column | Type | Constraints |
|---|---|---|
| `squad_id` | VARCHAR(36) | PK (composite), FK → squads ON DELETE CASCADE |
| `user_id` | VARCHAR(36) | PK (composite), FK → users ON DELETE CASCADE |
| `role` | ENUM | `leader`, `member` |

#### `schedules`
| Column | Type | Constraints |
|---|---|---|
| `id` | VARCHAR(36) | PK (UUID) |
| `squad_id` | VARCHAR(36) | FK → squads ON DELETE CASCADE |
| `shift_date` | DATE | NOT NULL |
| `start_time` | TIME | NOT NULL |
| `end_time` | TIME | NOT NULL |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP |

#### `attendance`
| Column | Type | Constraints |
|---|---|---|
| `id` | VARCHAR(36) | PK (UUID) |
| `user_id` | VARCHAR(36) | FK → users ON DELETE CASCADE |
| `schedule_id` | VARCHAR(36) | FK → schedules ON DELETE SET NULL (nullable) |
| `checkpoint_id` | VARCHAR(255) | |
| `latitude` | DECIMAL(10,8) | Clock-in GPS |
| `longitude` | DECIMAL(11,8) | Clock-in GPS |
| `clock_in_time` | DATETIME | |
| `clock_out_time` | DATETIME | Nullable (null = still on shift) |
| `clock_out_latitude` | DECIMAL(10,8) | |
| `clock_out_longitude` | DECIMAL(11,8) | |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP |

#### `incidents`
| Column | Type | Constraints |
|---|---|---|
| `id` | VARCHAR(36) | PK (UUID) |
| `user_id` | VARCHAR(36) | FK → users ON DELETE CASCADE |
| `title` | VARCHAR(255) | NOT NULL |
| `description` | TEXT | |
| `category` | VARCHAR(100) | JPNIN standard category |
| `image_url` | JSON | Array of image file paths |
| `latitude` | DECIMAL(10,8) | |
| `longitude` | DECIMAL(11,8) | |
| `status` | VARCHAR(50) | DEFAULT `Pending` |
| `location_name` | VARCHAR(255) | Reverse-geocoded address |
| `reported_to` | VARCHAR(100) | Agency name |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP |

> **Note**: Incident zone/district/state is derived from the reporter's `users` record via JOIN. Patrollers only report incidents within their assigned zone per SRS workflow.

#### `equipment_inventory`
| Column | Type | Constraints |
|---|---|---|
| `id` | VARCHAR(36) | PK (UUID) |
| `item_name` | VARCHAR(255) | NOT NULL |
| `total_quantity` | INT | NOT NULL |

**Seed data**: Vest, Cota/Baton, Lampu Suluh, Walkie-Talkie (4 items)

#### `equipment_logs`
| Column | Type | Constraints |
|---|---|---|
| `id` | VARCHAR(36) | PK (UUID) |
| `attendance_id` | VARCHAR(36) | FK → attendance ON DELETE CASCADE |
| `equipment_id` | VARCHAR(36) | FK → equipment_inventory ON DELETE CASCADE |
| `borrowed_at` | DATETIME | |
| `returned_at` | DATETIME | Nullable (null = still borrowed) |

### 4.3 Database Conventions
- All primary keys are `VARCHAR(36)` UUID v4 strings.
- All foreign keys use `ON DELETE CASCADE` (except `schedule_id` in attendance which is `SET NULL`).
- Charset: `utf8mb4` throughout.
- Timestamps: `TIMESTAMP DEFAULT CURRENT_TIMESTAMP`.
- Engine: InnoDB (for foreign key support).

### 4.4 Location Hierarchy

Malaysia's administrative structure relevant to SRS:

```
State (Negeri)
└── District (Daerah / PPD)
    └── Zone (Zon Rondaan) — SRS-specific patrol area within a district
```

**Current deployment hierarchy:**

| State | District | Zones |
|---|---|---|
| Melaka | Alor Gajah | Zon Pusat, Zon Utara, Zon Selatan, Zon Barat |
| Melaka | Jasin | Zon Timur |
| Melaka | Melaka Tengah | Zon Pusat, Zon Timur, Zon Barat |

**Registration cascading dropdown logic:**
```
State selector (e.g., "Melaka")
  └── District selector (filtered by selected state)
      └── Zone selector (filtered by selected district)
```

The location hierarchy is hardcoded as a hierarchical map in the Flutter app (acceptable for FYP scope):

```dart
const locationHierarchy = {
  'Melaka': {
    'Alor Gajah': ['Zon Pusat', 'Zon Utara', 'Zon Selatan', 'Zon Barat'],
    'Jasin': ['Zon Timur'],
    'Melaka Tengah': ['Zon Pusat', 'Zon Timur', 'Zon Barat'],
  },
  // Add more states as needed for future expansion
};
```

**Lampiran 6 zone-to-metadata mapping** (no longer hardcoded in PHP — derived from `users` table):
- `users.state` → PPD Negeri header in report
- `users.district` → PPD Daerah header in report
- `users.zone` → KRT zone identification in report

### 4.5 SQL Migration (from `district_zone` to `state`/`district`/`zone`)

```sql
-- Step 1: Add new columns
ALTER TABLE users
  ADD COLUMN state VARCHAR(100) NOT NULL DEFAULT 'Melaka' AFTER district_zone,
  ADD COLUMN district VARCHAR(100) NOT NULL DEFAULT 'Alor Gajah' AFTER state,
  ADD COLUMN zone VARCHAR(100) NOT NULL DEFAULT 'Zon Pusat' AFTER district;

-- Step 2: Migrate existing data
UPDATE users SET state = 'Melaka', district = 'Jasin', zone = 'Zon Timur'
  WHERE district_zone = 'Zon Timur';

UPDATE users SET state = 'Melaka', district = 'Alor Gajah', zone = district_zone
  WHERE district_zone != 'Zon Timur';

-- Step 3: Drop old column
ALTER TABLE users DROP COLUMN district_zone;

-- Step 4: Add indexes for filtering performance
ALTER TABLE users ADD INDEX idx_state (state);
ALTER TABLE users ADD INDEX idx_district (district);
ALTER TABLE users ADD INDEX idx_zone (zone);

-- Step 5: Add zone to squads table
ALTER TABLE squads ADD COLUMN zone VARCHAR(100) DEFAULT NULL AFTER name;

-- Step 6: Remove addendum table (no longer used)
DROP TABLE IF EXISTS incident_addendums;
```

### 4.6 GPS Column Type Fix

The current live database stores GPS coordinates as `VARCHAR(50)`. This must be migrated to `DECIMAL` for mathematical operations (e.g., Haversine distance calculations).

```sql
-- attendance table
ALTER TABLE attendance
  MODIFY COLUMN latitude DECIMAL(10,8) DEFAULT NULL,
  MODIFY COLUMN longitude DECIMAL(11,8) DEFAULT NULL,
  MODIFY COLUMN clock_out_latitude DECIMAL(10,8) DEFAULT NULL,
  MODIFY COLUMN clock_out_longitude DECIMAL(11,8) DEFAULT NULL;

-- incidents table
ALTER TABLE incidents
  MODIFY COLUMN latitude DECIMAL(10,8) NOT NULL,
  MODIFY COLUMN longitude DECIMAL(11,8) NOT NULL;
```

---

## 5. API Reference

### 5.1 Standard Response Format

**Every endpoint MUST return this exact JSON structure:**

```json
// Success
{
  "status": "success",
  "message": "Operation completed successfully",
  "data": { ... }
}

// Error
{
  "status": "error",
  "message": "Descriptive error message"
}
```

> ⚠️ **NEVER** use `{"success": true/false, ...}`. Some legacy endpoints use this — they must be migrated to the `"status"` format.

### 5.2 Endpoint Boilerplate

Every PHP endpoint MUST follow this template:

```php
<?php
header('Content-Type: application/json');
require_once '../config/db_connect.php';
require_once '../config/jwt_utils.php';

// 1. Method validation
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Invalid request method"]);
    exit;
}

// 2. JWT authentication (skip ONLY for login.php and register.php)
$token = get_bearer_token();
if (!$token) {
    http_response_code(401);
    echo json_encode(["status" => "error", "message" => "Missing authentication token"]);
    exit;
}
$decoded = verify_jwt($token);
if (!$decoded) {
    http_response_code(401);
    echo json_encode(["status" => "error", "message" => "Invalid or expired token"]);
    exit;
}
$user_id = $decoded['user_id'];
$user_role = $decoded['role'];

// 3. Endpoint logic (ALWAYS use prepared statements)
$stmt = $conn->prepare("SELECT ... WHERE id = ?");
$stmt->bind_param("s", $variable);
$stmt->execute();

// 4. Response
echo json_encode(["status" => "success", "message" => "...", "data" => [...]]);

$conn->close();
?>
```

### 5.3 Complete Endpoint Map

| Endpoint | Method | Auth | Purpose | Request | Response Data |
|---|---|---|---|---|---|
| `auth/login.php` | POST | No | Login | `email`, `password` | `{token, id, full_name, role, state, district, zone, account_status}` |
| `auth/register.php` | POST | No | Register | `id(UUID)`, `full_name`, `ic_number`, `phone_number`, `email`, `password`, `state`, `district`, `zone` | `{message}` |
| `auth/get_profile.php` | GET | **Yes** | Get user profile | `?user_id=` | `{id, full_name, ic_number, state, district, zone, ...}` |
| `auth/get_patrollers.php` | GET | **Yes** | List all patrollers | — | `[{id, full_name, role, state, district, zone, status}, ...]` |
| `incidents/upload_incident.php` | POST (multipart) | **Yes** | Submit incident | `id`, `user_id`, `title`, `description`, `category`, `latitude`, `longitude`, `location_name`, `reported_to`, `images[]` | `{message}` |
| `incidents/get_incidents.php` | GET | **Yes** | List incidents | `?user_id=` (optional) | `[{id, title, category, created_at, ...}, ...]` |
| `incidents/delete_incident.php` | POST | **Yes** | Delete incident | `incident_id` | `{message}` |
| `incidents/check_sos.php` | GET | **Yes** | Poll SOS alerts | `?exclude_user=` | `[{id, user_id, full_name, latitude, longitude, created_at}, ...]` |
| `incidents/get_lampiran_6_summary.php` | GET | **Yes** | Monthly stats | `?month_offset=&level=&user_id=` | `{metadata: {negeri, daerah, nama_srs}, data: {...}}` |
| `attendance/clock_in.php` | POST | **Yes** | QR clock-in | `user_id`, `checkpoint_id`, `latitude`, `longitude`, `qr_token` | `{attendance_id, message}` |
| `attendance/clock_out.php` | POST | **Yes** | Clock-out | `user_id`, `attendance_id` | `{message}` |
| `attendance/log_equipment.php` | POST | **Yes** | Log equipment | `attendance_id`, `equipment_items[]` | `{message}` |
| `equipment/get_inventory.php` | GET | **Yes** | Equipment list | — | `[{id, item_name, total_quantity, available}, ...]` |
| `admin/squads.php` | GET | **Yes** | List squads | — | `[{id, name, zone, members: [...]}, ...]` |
| `admin/squads.php` | POST | **Yes** | Squad CRUD | `action` (create_squad/add_member/remove_member/delete_squad) + params | `{message}` |
| `admin/schedules.php` | GET | **Yes** | List schedules | — | `[{id, squad_id, squad_name, shift_date, ...}, ...]` |
| `admin/schedules.php` | POST | **Yes** | Schedule CRUD | `action` (create_schedule/delete_schedule) + params | `{message}` |
| `admin/get_stats.php` | GET | **Yes** | Dashboard KPIs | — | `{total_patrollers, active_shifts, weekly_incidents}` |
| `admin/get_active_shifts.php` | GET | **Yes** | Active shifts | — | `[{user_id, full_name, clock_in_time, ...}, ...]` |

### 5.4 Security Rules

- **ALWAYS** use prepared statements with `bind_param()`. **NEVER** concatenate user input into SQL.
- **ALWAYS** validate `$_SERVER['REQUEST_METHOD']` at the top of every endpoint.
- **ALWAYS** hash passwords with `password_hash($pw, PASSWORD_BCRYPT)`.
- **ALWAYS** enforce JWT on all endpoints except `login.php` and `register.php`.
- **ALWAYS** extract `user_id` from the JWT token payload — never trust client-sent `user_id`.
- Image uploads MUST be saved to `uploads/incidents/` with a UUID-based filename.
- JWT secret: `JWT_SECRET` defined in `jwt_utils.php` — **never commit to public repos**.

---

## 6. Feature Catalog

### 6.1 QR Attendance System (Anti-Cheat)

**QR Generation** (Admin/Ketua → `qr_generator_screen.dart`):
1. Admin taps "Generate QR" → app reads GPS via `geolocator`.
2. QR payload format: `SRS_ATTENDANCE|{latitude}|{longitude}|{UTC_timestamp}`
3. QR displayed via `QrImageView` with 60-second countdown timer.
4. Auto-expires: visual expired state with `timer_off` icon + regenerate button.
5. GPS location auto-reverse-geocoded to district name via `geocoding`.

**QR Scanning** (Patroller → `attendance_screen.dart`):
1. Camera-based QR scan via `MobileScanner`.
2. Dark-themed scanner UI with torch toggle and camera flip buttons.
3. On scan → `AttendanceProvider.processQrScan()`:
   - Parse QR payload → extract lat, lon, timestamp.
   - Validate timestamp freshness (≤60 seconds old).
   - **Haversine distance** check: patroller must be within ~100m of admin GPS anchor.
4. On success → equipment checkout dialog:
   - `AlertDialog` with `CheckboxListTile` items from `equipment_inventory`.
   - Selected equipment logged via `attendance/log_equipment.php`.
5. Shift state persisted in `SharedPreferences`: `shiftActive`, `activeCheckpoint`, `shiftStartTime`.

**Clock-Out** (Patroller → `dashboard_screen.dart`):
1. "End Shift Early" button on dashboard.
2. Calls `attendance/clock_out.php` → marks `clock_out_time` and `returned_at` on equipment logs.
3. Clears shift state from `SharedPreferences`.

### 6.2 Incident Reporting

**Report Submission** (`incident_report_screen.dart`):
1. Responsive layout (`LayoutBuilder` — split-screen on wide displays).
2. JPNIN category picker: `showModalBottomSheet` with searchable list of 24 categories.
3. "Reported To" agency picker: `showModalBottomSheet` with 5 agency options.
4. Multi-image capture via `ImagePicker` (camera) → grid preview with remove buttons.
5. GPS auto-attach via `geolocator` → reverse-geocoded to `location_name`.
6. Submit via `IncidentService.submitReport()` using `http.MultipartRequest`.

**Incident Feed** (`incident_screen.dart`):
- `TabBar` with time filters: Harian (today), Mingguan (this week), Semua (all).
- `ListView.builder` with incident cards.
- Role-based filtering: `peronda` sees own incidents only; admin sees all.
- Zone filtering via dropdown.
- `PopupMenuButton` on each card for delete action.

**Incident Detail** (`incident_detail_screen.dart`):
- Full incident metadata display.
- Image carousel with `PageView` + `InteractiveViewer` (pinch-zoom, double-tap zoom).
- PDF generation: single-incident report using `pdf` package → `PdfPreview` widget.

### 6.3 Lampiran 6 — Monthly JPNIN Statistical Report

**Current state** (`lampiran_6_screen.dart`, 867 lines):
- Month/year picker via custom `showMonthPicker`.
- Level selector: Daerah (district) vs Negeri (state) — `SegmentedButton`.
- `DataTable` with 7 columns: Category × 5 agencies + total + grand total.
- Full JPNIN-standard 24-category structure with section subtotals.
- PDF generation with official government form layout including signatures block.
- API: `incidents/get_lampiran_6_summary.php?month_offset=X&level=daerah|negeri&user_id=Y`.

**Planned redesign**:
- Card-list view sorted by zone and state for each month (Dribbble reference: card list items UI kit style).
- Filter bar: zone, state, month selectors.
- Preview modal (vertical popup) to view document before export.
- Show crime hotspot zones with highest incident counts when no filter is applied.
- Zone-level filtering to generate reports per zone (Zon Pusat/Timur/Utara/Selatan/Barat) or "Semua".

### 6.4 SOS Emergency System

**Trigger** (`map_screen.dart` → to be renamed `sos_screen.dart`):
- Large circular red SOS button (220×220).
- Confirmation dialog → success dialog with GPS info.
- Creates an incident of category `Kecemasan` via `TrackingProvider.triggerSos()`.

**Reception** (`sos_alert_service.dart` — Singleton):
- Polls `incidents/check_sos.php?exclude_user=X` every **10 seconds**.
- On new SOS: vibration pattern, system notification (`flutter_local_notifications`), modal dialog overlay.
- Tracks notified SOS IDs in memory to prevent duplicate alerts.
- Uses `GlobalKey<NavigatorState>` to show dialogs from background service.
- "Open in Maps" button launches Google Maps via `url_launcher` with SOS coordinates.

**Planned enhancement**: Inline `flutter_map` (OpenStreetMap) widget to view SOS location without leaving the app.

### 6.5 Analytics Dashboard

**Current state** (`analytics_screen.dart`, 514 lines):
- 3 KPI cards: Weekly Incidents, Active Shifts, Registered Patrollers.
- `LineChart` (7-day incident trend) via `fl_chart`.
- Live patrol feed: list of currently active patrollers with animated pulsing green dot.
- "Generate Lampiran 6" button → navigates to Lampiran 6 screen.

**Planned comprehensive analytics**:
- **Weekly/Monthly crime trends** — line chart with period toggle.
- **Category breakdown** — pie/donut chart showing distribution of 24 JPNIN categories.
- **Zone heatmap comparison** — bar chart comparing incident counts across 5 zones.
- **Top 5 hotspot zones** — ranked list with incident count badges.
- **Severity distribution** — breakdown by crime group (A: Violent, B: Property, C: Other, D: Misc).
- **Patrol effectiveness** — correlation metric: incidents per patrol hour.

### 6.6 Squad & Schedule Management

**Squad Management** (`admin_squad_schedule_screen.dart` — Squad Tab):
- Create squad: dialog with name input.
- Expandable `ExpansionTile` per squad showing member list.
- Add member: dialog with patroller list picker from `auth/get_patrollers.php`.
- Remove member: swipe-to-delete or button with confirmation.
- Delete squad: confirmation dialog with cascade warning.

**Schedule Management** (Schedule Tab):
- Create schedule: `showModalBottomSheet` with:
  - Squad dropdown picker.
  - Date picker (`showDatePicker`).
  - Start time picker (`showTimePicker`).
  - End time picker (`showTimePicker`).
- Schedule list with delete action.

**Planned enhancements**:
- Calendar view for patrollers showing their upcoming scheduled shifts in a modal.
- Push notification when a shift is approaching.
- Phone calendar integration (add shift to device calendar).
- Batch member selection: multi-select patrollers with checkboxes instead of one-by-one.

### 6.7 Equipment Tracking (LAMPIRAN SRS C2) (Implementation needed)
Create new screen for equipment tracking with QR scanner to check in and check out equipment.

**Current state**:
- Equipment checkout during clock-in (`attendance_screen.dart`): checkbox dialog.
- Equipment inventory API (`equipment/get_inventory.php`).
- Equipment log API (`attendance/log_equipment.php`): records borrowing.
- Auto-return on clock-out (`attendance/clock_out.php`): marks `returned_at`.

**Seed equipment**: Vest, Cota/Baton, Lampu Suluh (Flashlight), Walkie-Talkie.


### 6.8 Dashboard — Patroller Home

**Current state** (`dashboard_screen.dart`, 19KB):
- 7-day incident trend bar chart (`fl_chart` BarChart).
- SOS alert feed with "Open in Maps" action.
- "Start Shift" / "End Shift Early" toggle buttons.
- GPS location permission handling with custom dialog.
- `RefreshIndicator` for pull-to-refresh.
- Responsive layout via `LayoutBuilder`.

### 6.9 Authentication Screens

**Login** (`login_screen.dart`):
- Responsive split-screen layout (>800px: hero illustration + form side-by-side).
- Email + password fields with validation.
- "Forgot password?" link (non-functional placeholder).(implementation needed)
- Error feedback via `SnackBar`.

**Registration** (`register_screen.dart`):
- Form with: full_name, IC number, phone, email, password.
- 3 cascading dropdowns: State → District → Zone (hardcoded location hierarchy map).(admin can add new zone, district, state from admin panel in user management tab)
- `Form` with `GlobalKey<FormState>` for validation.
- Success dialog → return to login.
- Newly registered users default to `pending` status (need admin approval).

**Profile** (`profile_screen.dart`):
- Read-only display of user data.
- `CircleAvatar` with user initial.
- Info rows with icons for each field.
- Loading and error states.

---

## 7. Design System

### 7.1 Brand Colours

| Token | Hex | RGB | Usage |
|---|---|---|---|
| Primary | `#0F3D87` | (15, 61, 135) | AppBar, primary buttons, focused inputs, nav selected state |
| Secondary / Accent | `#FFD100` | (255, 209, 0) | Highlights, badges, accent indicators |
| Charcoal | `#2C3E50` | (44, 62, 80) | Used in some card headers and text |
| Scaffold Background | `#F8F9FA` | (248, 249, 250) | Page background |
| Card Surface | `#FFFFFF` | White | Card backgrounds, bottom sheets, dialogs |
| Error / Destructive | Material `Colors.red` | — | Delete buttons, error states |
| Success | Material `Colors.green` | — | Active indicators, success feedback |
| Text Primary | `Colors.black87` | — | Primary body text |
| Text Secondary | `Colors.grey.shade600` | — | Labels, hints, metadata |

### 7.2 Typography

- **AppBar title**: 20sp, `FontWeight.w600`, letter-spacing 0.5, white.
- **Body text**: System default (Material Roboto).
- **Button text**: 16sp, `FontWeight.bold`, letter-spacing 1.
- **Card labels**: Material default sizing with grey hints.
- **PDF generation**: Uses `google_fonts` Roboto for PDF rendering.

### 7.3 Layout & Responsiveness

**Breakpoints & Pane Strategy:**

| Width | Classification | Layout |
|---|---|---|
| < 600px | Compact (phone portrait) | Single pane, `BottomNavigationBar` |
| 600–800px | Medium (phone landscape / small tablet) | 1–2 panes, evaluate case-by-case |
| > 800px | Large (tablet / desktop / web) | Multi-pane, horizontal top navigation bar |

**Layout Rules:**
- **MUST** consider different aspect ratios, size classes, and resolutions.
- **MUST** verify good UX on both landscape and portrait orientations.
- **MUST** set a max width on content and components to prevent stretching.
- **MUST** allow components to adapt presentation (e.g., bottom sheet → side sheet at larger sizes).
- **MUST** ensure inputs and buttons are NOT stretched on wide screens.
- **MUST** use containment concept of **panes** to group content for adaptive layouts.
- **MUST** honor device safe areas: display cutouts, edge-to-edge insets, system bars, software keyboard.
- **MUST** provide flexible layout for keyboard interaction — be careful not to cover content.

**`ResponsiveShell` (core/widgets/responsive_shell.dart):**
- Breakpoint at 800px.
- Large: Horizontal top navigation bar with logo, centered nav items, right-side actions.
- Small: `BottomNavigationBar` with `BackdropFilter` glass effect (gaussian blur σ=10).
- SOS button injected at center position of bottom nav bar (for `peronda` and `ketua_peronda`).

### 7.4 Modals & Dialogs

**Standard: Use `showModalBottomSheet` for all creation/editing forms and confirmations.**
**Reserve `AlertDialog` ONLY for simple yes/no confirmations.**

| Use Case | Widget | Details |
|---|---|---|
| Creation forms (incident, squad, schedule) | `showModalBottomSheet` | `isScrollControlled: true`, `DraggableScrollableSheet`, rounded top corners (20px) |
| Editing forms (profile edit, addendum) | `showModalBottomSheet` | Same as creation |
| Selection pickers (category, agency, member) | `showModalBottomSheet` | Searchable list inside |
| Yes/No confirmation (delete, logout) | `AlertDialog` | Two-button layout: TextButton (cancel) + FilledButton (confirm) |
| Success/Error feedback | `SnackBar` | M3 style, 4-second duration |
| Preview (PDF, document) | Vertical popup modal | Full-height bottom sheet or dialog |

**Bottom Sheet Standards:**
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (context) => DraggableScrollableSheet(...),
);
```

### 7.5 Buttons (Material 3 Hierarchy)

| Level | Widget | Usage | Styling |
|---|---|---|---|
| **Primary (highest emphasis)** | `FilledButton` | Main CTA actions (Submit, Save, Login) | Navy background, white text |
| **Secondary** | `FilledButton.tonal` | Supporting actions (Filter, Generate) | Light navy tonal, navy text |
| **Tertiary** | `OutlinedButton` | Alternative actions (Cancel, Back) | Navy border, transparent background |
| **Lowest emphasis** | `TextButton` | Dismiss, skip, "Forgot password?" | Navy text only, no border/fill |
| **Destructive** | `FilledButton` | Delete, remove | Red background, white text |
| **FAB / SOS** | `FloatingActionButton` | Primary creation action / emergency | Navy (create) or Red (SOS) |

**Button Sizing:**
- Full-width buttons in forms: `padding: EdgeInsets.symmetric(vertical: 16)`.
- All buttons: `BorderRadius.circular(16)`.
- Icon buttons: 48×48 minimum touch target.

### 7.6 Text Inputs (Material 3 Underline Style)

**Migrate from outlined to Material 3 underline-style inputs:**

```dart
InputDecorationTheme(
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  border: const UnderlineInputBorder(),
  enabledBorder: UnderlineInputBorder(
    borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
  ),
  focusedBorder: const UnderlineInputBorder(
    borderSide: BorderSide(color: Color(0xFF0F3D87), width: 2),
  ),
  labelStyle: TextStyle(color: Colors.grey.shade600),
)
```

**Rules:**
- Prefix icons for context (email → `Icons.email`, password → `Icons.lock`).
- Suffix icons for actions (clear → `Icons.clear`, visibility toggle).
- Floating labels.
- Inline validation with error text below field.

### 7.7 Date & Time Pickers

| Scenario | Widget | Notes |
|---|---|---|
| Single date selection | `showDatePicker()` (Material 3) | Navy primary color theme |
| Date range selection | `calendar_date_picker2` | For filtering incident lists |
| Time selection | `showTimePicker()` (Material 3) | For schedule start/end times |
| Month/year selection | Custom `showMonthPicker` | For Lampiran 6 report period |

**Reference**: Follow [Android Material Design documentation](https://developer.android.com/develop/ui/compose/documentation) patterns.

### 7.8 Selection Widgets (Material 3)

| Scenario | Widget | When to Use |
|---|---|---|
| 2–4 fixed options | `SegmentedButton` | Tab-like choices (e.g., Daerah/Negeri, Harian/Mingguan) |
| Multi-select filters | `FilterChip` | Zone filters, category filters |
| Long option lists (5+) | `DropdownMenu` (M3) | Zone selector, squad picker |
| Searchable selection | `showModalBottomSheet` with search | Category picker, member picker |

**NEVER use** `DropdownButtonFormField` — it is deprecated in favour of `DropdownMenu`.

### 7.9 Notifications & Feedback

| Type | Widget | Behaviour |
|---|---|---|
| Quick success/error toast | `SnackBar` (M3 style) | 4-second auto-dismiss, bottom of screen |
| Field validation error | Inline error text | Red text below the field via `FormField.validator` |
| Network failure | Full-screen error state | Centered icon + message + "Retry" `FilledButton` |
| Background operation | `LinearProgressIndicator` in AppBar | For uploads, long-running operations |
| SOS alert | Modal dialog overlay | Via `SosAlertService` with vibration + sound |
| System push notification | `flutter_local_notifications` | SOS alerts when app is backgrounded |

**Reference**: Follow [Material 3 SnackBar guidelines](https://m3.material.io/).

### 7.10 Loading States

**Use skeleton/shimmer loading throughout for a premium feel.**

| Context | Approach |
|---|---|
| Lists (incidents, patrollers, schedules) | Shimmer skeleton cards matching the real card layout |
| Detail screens | Shimmer skeleton matching header + body layout |
| Charts | Shimmer skeleton matching chart dimensions |
| Form submission | `FilledButton` shows `CircularProgressIndicator` inside (replaces text) |
| Full-page initial load | Centered `CircularProgressIndicator` with navy color |
| Pull-to-refresh | `RefreshIndicator` (Material default) |

### 7.11 Cards

```dart
CardTheme(
  color: Colors.white,
  elevation: 3,
  shadowColor: Colors.black12,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
)
```

**Card Patterns:**
- **Stat cards** (dashboard): Glassmorphic with gradient overlay.
- **List item cards** (incidents, patrollers): Horizontal layout with thumbnail, metadata, action icons.
- **KPI cards** (analytics): Icon + number + label, flat color accent.

### 7.12 Navigation

**Bottom Navigation Bar** (compact screens):
- `BackdropFilter` with gaussian blur (σ=10) for glass effect.
- Selected: navy icon + label (12sp, w600). Unselected: grey (11sp).
- SOS FAB centered at bottom bar (for peronda/ketua_peronda roles).

**Top Navigation Bar** (large screens):
- Horizontal bar with logo left, nav items center, actions right.
- Active tab: underline indicator.

### 7.13 AppBar

```dart
AppBarTheme(
  backgroundColor: Color(0xFF0F3D87),  // Navy
  foregroundColor: Colors.white,
  elevation: 0,
  centerTitle: true,
  titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.5),
)
```

**Rules:**
- Leading: back button (auto) or menu icon.
- Title: centered, always.
- Trailing: action icons (settings, filter, overflow menu).

### 7.14 Empty States

When a list has no data, show:
- Centered illustration/icon (subdued grey).
- Descriptive text explaining why it's empty.
- Optional CTA button if user can create content.

### 7.15 Image Handling

**Image Viewer** (`image_viewer_screen.dart`):
- `PageView` for multi-image carousel.
- `InteractiveViewer` for pinch-to-zoom.
- Double-tap zoom toggle via `TransformationController` with animation.
- Page indicator dots at bottom.

**Image Thumbnails** (in card lists):
- ~90×120px from left side of card.
- Rounded corners matching card radius.
- Placeholder icon if no image available.

---

## 8. Coding Conventions

### 8.1 Dart / Flutter

| Convention | Pattern | Example |
|---|---|---|
| File names | `snake_case.dart` | `auth_provider.dart`, `login_screen.dart` |
| Class names | `PascalCase` | `AuthProvider`, `LoginScreen` |
| Variables & methods | `camelCase` | `isAuthenticated`, `fetchIncidents()` |
| Constants | `camelCase` in constant classes | `baseUrl`, `loginEndpoint` |
| Private members | `_camelCase` | `_isLoading`, `_handleSubmit()` |
| Screen suffix | `*Screen` | `LoginScreen`, `AttendanceScreen` |
| Provider suffix | `*Provider` | `AuthProvider`, `IncidentProvider` |
| Service suffix | `*Service` | `AuthService`, `AttendanceService` |
| Model suffix | `*Model` | `UserModel` |
| JSON keys | `snake_case` | Matching PHP/MySQL column names |
| Widget suffix | Descriptive | `ResponsiveShell`, `GlobalMenuButton` |
| Comments language | English | Code comments in English |
| User-facing strings | Malay default | Via `settings.t('key')` with both `ms`/`en` |

### 8.2 PHP

| Convention | Pattern | Example |
|---|---|---|
| File names | `snake_case.php` | `clock_in.php`, `get_stats.php` |
| Variables | `$snake_case` | `$user_id`, `$shift_date` |
| Response keys | `snake_case` | `"user_id"`, `"full_name"` |
| Style | Procedural only | **No OOP wrappers**, no classes |
| String quotes | Double quotes for JSON keys | `"status" => "success"` |

### 8.3 General Rules

- **Logging**: Use `appLogger` instance (from `core/utils/logger.dart`). **NEVER** use `print()` or `debugPrint()`.
- **UUIDs**: All entity IDs are v4 UUIDs — generated client-side via `uuid` package or server-side via `sprintf('%04x%04x-...', mt_rand(...))`.
- **Language**: Default locale is `ms` (Bahasa Melayu). ALL new user-facing strings MUST be added to `SettingsProvider` translation map for both `ms` and `en`.
- **Imports**: Keep imports organized — Dart/Flutter SDK first, then packages, then project files. Use relative imports within the same feature module.
- **File size**: If a file exceeds ~500 lines, consider extracting reusable widgets into separate files.

---

## 9. Known Bugs & Issues

### 🔴 CRITICAL

| ID | File | Lines | Description | Suggested Fix |
|---|---|---|---|---|
| BUG-001 | `equipment/get_inventory.php` | Entire file | Uses PDO methods (`fetchAll(PDO::FETCH_ASSOC)`) but `db_connect.php` provides a **mysqli** connection → **will crash at runtime** | Rewrite using `mysqli` prepared statements: `$stmt->get_result()->fetch_all(MYSQLI_ASSOC)` |
| BUG-002 | No file | — | `tracking/sos_alert.php` referenced by `TrackingService` but **does not exist** in the API directory | Create the endpoint or redirect SOS to use `incidents/upload_incident.php` with category `Kecemasan` |

### 🟠 HIGH

| ID | File | Lines | Description | Suggested Fix |
|---|---|---|---|---|
| BUG-003 | `admin_squad_schedule_screen.dart` | ~616 | `DropdownButtonFormField` uses `initialValue` parameter which **does not exist** — should be `value` | Replace with `DropdownMenu` (M3) and use `initialSelection` parameter |
| BUG-004 | Multiple API files | — | JWT authentication is **not enforced** — endpoints trust client-sent `user_id` | Add JWT verification boilerplate to ALL endpoints except login/register |
| BUG-005 | `incident_screen.dart` | Delete handler | Deleting an incident does NOT cascade-delete uploaded images from server filesystem | Add image file deletion logic in `delete_incident.php` using `unlink()` |
| BUG-006 | `dashboard_screen.dart` | Shift state | Shift state stored only in `SharedPreferences` — NOT synced with server on app restart (stale state) | On app launch, check server for active attendance record and sync local state |

### 🟡 MEDIUM

| ID | File | Lines | Description | Suggested Fix |
|---|---|---|---|---|
| ~~BUG-007~~ | `attendance_screen.dart` | Multiple | ~~Hardcoded dark theme colors (`Color(0xFF1E1E1E)`) instead of using `Theme.of(context)`~~ [RESOLVED] | Replace all hardcoded colors with theme references |
| ~~BUG-008~~ | `analytics_screen.dart` | Multiple | ~~Hardcoded `Colors.white`, `Colors.black87`, `Colors.grey.shade50` — doesn't respect theme~~ [RESOLVED] | Use `Theme.of(context).colorScheme.*` |
| BUG-009 | `api_client.dart` vs services | — | Inconsistent HTTP call patterns: `ApiClient` uses form-encoded body, `TrackingService` sends JSON body, `IncidentService` uses raw `MultipartRequest` | Standardize: form-encoded for simple POST, MultipartRequest for file uploads |
| BUG-010 | `api_constants.dart` | Line 4 | Base URL hardcoded to `http://10.131.77.105/srs_api/` — won't work on other networks | Use environment-based config or fallback chain |
| BUG-011 | Multiple | — | Stored image URLs contain hardcoded host IPs (e.g., `http://192.168.1.109/...`) that become stale | Store relative paths in DB, construct full URL at API response time using server's own base URL |
| BUG-012 | `incidents/fetch_incidents.php` | Entire file | Dead code — exists in API but is NOT called by any Flutter code | Remove or integrate into the app |
| BUG-013 | `get_incidents.php` (root level) | Entire file | Duplicate endpoint at root level — legacy file | Remove; use `incidents/get_incidents.php` |

### 🔵 LOW

| ID | File | Lines | Description | Suggested Fix |
|---|---|---|---|---|
| ~~BUG-014~~ | `admin_member_screen.dart` | Edit handler | ~~"Kemas Kini" (Update) action is a **stub** — shows "coming soon" snackbar~~ [RESOLVED] | Build full user management feature |
| BUG-015 | `login_screen.dart` | Forgot link | "Forgot password?" link is **non-functional** | Implement password reset or remove the link |
| BUG-016 | `profile_screen.dart` | Entire file | Profile is **read-only** — no edit capability | Add profile editing (at minimum: phone, name) |
| BUG-017 | `main.dart` | Line 47 | `themeMode: ThemeMode.light` hardcoded — dark theme code is dead | Remove dark theme code entirely (per project decision) |
| BUG-018 | `register_screen.dart` | Zone dropdown | Zone list is hardcoded in Flutter — not fetched from API | OK for FYP scope; document as known limitation |
| ~~BUG-019~~ | `settings_provider.dart` | — | ~~Missing translation keys for: squad management screens, equipment dialog, some analytics labels~~ [RESOLVED] | Add missing `ms`/`en` translation pairs |

---

## 10. Planned Features

### 10.1 User Management (Admin) — TO BUILD

**Scope**: Admin (`ketua_krt`) manages user accounts.

| Action | Description |
|---|---|
| **Approve/Reject** | Review `pending` users and approve (set `active`) or reject (set `inactive`) |
| **Activate/Deactivate** | Toggle existing users between `active` and `inactive` (disable login) |
| **Promote Role** | Change user role (e.g., `peronda` → `ketua_peronda`) |

**Implementation**: Extend `admin_member_screen.dart` (currently a stub with "coming soon" snackbar). Add new API endpoints:
- `admin/update_user.php` — POST: `{action: approve|reject|activate|deactivate|promote, user_id, new_role?}`

### 10.2 Batch Selection — TO BUILD

**Where it applies:**

| Context | Batch Action | UX Pattern |
|---|---|---|
| **Squad member assignment** | Select multiple patrollers at once (max 20) via checkboxes, then bulk-add to squad | Multi-select `CheckboxListTile` in bottom sheet → single API call |
| **Incident management** | Select multiple incidents via checkboxes → bulk delete, bulk export to PDF, bulk status change | Checkbox on each card; header bar transforms to show batch action icons (delete, export) |
| **PDF batch download** | Select multiple monthly reports for batch PDF download | Checkbox on each Lampiran 6 card |

**UX Pattern for batch mode:**
1. Tap checkbox icon in header toolbar → enter batch selection mode.
2. Each list item shows a checkbox on the left.
3. Header toolbar transforms: left shows "X selected" count, right shows action buttons (delete icon, submit icon, export icon).
4. Deselect all / confirm actions.

### 10.3 Incident Feed Redesign — TO BUILD

**Header Area (below AppBar):**
- **Left side**: "Today" tab and "Archive" tab (for previous files).
- **Right side** (same level, horizontal icon row):
  1. Batch selection icon (checker icon) → enters multi-select mode.
  2. Category/filter picker icon (funnel icon) → opens filter bottom sheet (date, zone).
  3. Folder creation icon (folder icon) → creates a grouping folder.

**Primary action**: Change "Report Incident" button to a "+" FAB button.

**Document List View** (incident cards):
- Card dimensions: ~1080×170px (responsive).
- Layout per card:
  - **Left**: Image thumbnail (~90×120px) — if patroller snapped photos.
  - **Center**: Text & metadata (~750px area) — title, category, timestamp, zone.
  - **Right**: Three-dot menu icon (edit, delete) + separate submit icon (48×48 each).
- Reference design: [Octiv Document Lists on Dribbble](https://dribbble.com/shots/3650463-Octiv-Document-Lists).

**Batch mode behavior:**
- When batch mode is active, the right-side header icons change to: delete icon button + submit icon button.
- Each card shows a leading checkbox.
- Actions apply to all selected items.

### 10.4 Scheduling with Notifications — TO BUILD

**Enhancements to schedule system:**

| Feature | Description |
|---|---|
| **Calendar modal for patrollers** | Patrollers can view their upcoming scheduled shifts in a modal calendar view |
| **Push notifications** | Notify patrollers when a shift is approaching (e.g., 1 hour before, 15 min before) |
| **Phone calendar integration** | Option to add shift to device calendar app |

### 10.5 Lampiran 6 Redesign — TO BUILD

**New card-list design:**
- Monthly reports displayed as card list items (reference: [Dribbble card list UI kit](https://dribbble.com/shots/25365133-Cards-List-Items-UI-Kit)).
- Cards sorted by zone and state.
- Zone filter, state filter, month filter bar.
- Tap card → vertical preview modal showing document.
- Default view (no filter): show hotspot zones with highest crime counts.
- Zone options: Zon Pusat, Timur, Utara, Selatan, Barat, Semua.

### 10.6 SOS Map Integration — TO BUILD

- Replace `MapScreen` name to `SosScreen`.
- Add `flutter_map` (OpenStreetMap) widget for inline SOS location viewing.
- Show SOS marker on map when viewing an active SOS alert.

### 10.7 Remove Dead Code — TO BUILD

| Item | Action |
|---|---|
| `flutter_webrtc` dependency | Remove from `pubspec.yaml` |
| `google_mlkit_face_detection` dependency | Remove from `pubspec.yaml` |
| `camera` dependency | Evaluate if still needed (may be replaced by `image_picker` alone) |
| `communication/views/radio_screen.dart` | Delete file |
| `incident/services/privacy_service.dart` | Delete file (47-byte placeholder) |
| `incident/views/addendum_report_screen.dart` | Delete file (addendum feature removed) |
| `incidents/addendum.php` | Delete API endpoint (addendum feature removed) |
| `incidents/get_addendums.php` | Delete API endpoint (addendum feature removed) |
| `uploads/addendums/` | Delete directory (addendum feature removed) |
| Dark theme code in `main.dart` | Remove `darkTheme: ThemeData(...)` block entirely |
| Theme toggle in `GlobalMenuButton`/settings | Already removed — verify no dead code remains |
| `incidents/fetch_incidents.php` | Remove (dead/unused endpoint) |
| `get_incidents.php` (root level) | Remove (duplicate legacy file) |

---

## 11. Skills & References

### 11.1 Agent Skills — When to Use

| Task Domain | Skill to Use | Trigger |
|---|---|---|
| **Flutter architecture** | `flutter-apply-architecture-best-practices` | Structuring features, refactoring modules, layer separation |
| **Responsive layouts** | `flutter-build-responsive-layout` | Building adaptive UI for phone/tablet/web breakpoints |
| **Frontend design & polish** | `impeccable` | UI audits, visual hierarchy, typography, color, motion, micro-interactions, UX copy |
| **Aesthetic direction** | `frontend-design` | Making intentional visual design choices, avoiding templated defaults |
| **Architecture improvement** | `improve-codebase-architecture` | Finding refactoring opportunities, consolidating tightly-coupled modules |
| **Skill discovery** | `find-skills` | Finding new skills for unfamiliar tasks |
| **Plan stress-testing** | `grill-me` | Validating a plan through interactive interview |
| **Token efficiency** | `caveman` | Reducing response verbosity when token limits are a concern |

### 11.2 Troubleshooting Decision Tree

```
Bug detected
├── Flutter compile error?
│   ├── Widget doesn't exist → Check Flutter API docs for correct widget name
│   ├── Parameter doesn't exist → Check widget constructor signature
│   └── Type mismatch → Verify provider types and JSON parsing
│
├── PHP runtime error?
│   ├── Database error → Check db_connect.php (mysqli vs PDO mismatch?)
│   ├── JSON parse error → Check response format ({"status": ...} consistency)
│   ├── 401/403 error → Check JWT token handling in jwt_utils.php
│   └── File not found → Verify endpoint path matches ApiConstants
│
├── UI layout issue?
│   ├── Overflow → Use `Flexible`/`Expanded`, check text overflow with `TextOverflow.ellipsis`
│   ├── Not responsive → Use `LayoutBuilder` with breakpoints (800px)
│   ├── Hardcoded colors → Replace with `Theme.of(context).colorScheme.*`
│   └── Wrong widget → Consult Material 3 component catalog
│
├── State not updating?
│   ├── Provider not notifying → Ensure `notifyListeners()` is called
│   ├── Wrong context → Check `Consumer<T>` vs `context.watch<T>()` placement
│   └── SharedPreferences stale → Verify async read on app start
│
└── API data issue?
    ├── Empty response → Check PHP `echo json_encode(...)` and `$conn->close()`
    ├── Wrong data shape → Compare Flutter model `fromJson` with PHP response keys
    └── Images not loading → Check stored URL path vs current server IP
```

### 11.3 Official Documentation References

| Domain | Reference |
|---|---|
| **Flutter widgets** | https://api.flutter.dev/ |
| **Material 3 design** | https://m3.material.io/ |
| **Material 3 components** | https://m3.material.io/components |
| **Android UI guidelines** | https://developer.android.com/develop/ui/compose/documentation |
| **Flutter state management** | https://docs.flutter.dev/data-and-backend/state-mgmt/simple |
| **Provider package** | https://pub.dev/packages/provider |
| **fl_chart** | https://pub.dev/packages/fl_chart |
| **flutter_map (OSM)** | https://pub.dev/packages/flutter_map |
| **PHP manual** | https://www.php.net/manual/en/ |
| **MySQL reference** | https://dev.mysql.com/doc/refman/8.0/en/ |
| **JWT specification** | https://jwt.io/introduction |

### 11.4 Design References

| Area | Reference |
|---|---|
| Document list views | https://dribbble.com/shots/3650463-Octiv-Document-Lists |
| Card list items | https://dribbble.com/shots/25365133-Cards-List-Items-UI-Kit |
| Material 3 SnackBar | https://m3.material.io/ |

---

## 12. Do's and Don'ts

### ✅ DO

- Follow the feature-first folder structure (`features/<name>/{models,providers,services,views}/`).
- Use `Provider` + `ChangeNotifier` for state management.
- Use prepared statements in ALL PHP queries.
- Enforce JWT authentication on all API endpoints (except login/register).
- Extract `user_id` from JWT token — never trust client-sent user_id.
- Add bilingual translations (`ms`/`en`) for every new user-facing string.
- Use `appLogger` for logging (never `print()` or `debugPrint()`).
- Keep API responses in `{"status": "success/error", "message": "...", "data": {...}}` format.
- Generate UUIDs for all new entity IDs.
- Test responsive layouts on both phone and web/tablet for admin screens.
- Use Material 3 widgets: `FilledButton`, `SegmentedButton`, `DropdownMenu`, `FilterChip`.
- Use skeleton/shimmer loading for premium feel.
- Use `showModalBottomSheet` for forms; `AlertDialog` only for yes/no.
- Set max content width to prevent stretching on large screens.
- Honor device safe areas (notches, system bars, keyboard).
- Use `Theme.of(context)` for all colors — never hardcode color values in widgets.
- Follow Material 3 underline-style for text inputs.
- Check on the missed out bilingual translation from the old code.
- Remind me what is the next feature to build.
- Always follow the CONTEXT.md, use skill on each aspect whenever there is lacking during implementation, example if UI design is not explain clearly, use `impeccable` skill.
- Always follow the documentation and best practices for each aspect.
- Ask me if I satisfied with the implementation plan first before moving on to the next step.
### ❌ DON'T

- Don't introduce new state management libraries (no Riverpod, BLoC, GetX).
- Don't use `print()` or `debugPrint()` — use `appLogger`.
- Don't concatenate user input into SQL strings — ALWAYS prepared statements.
- Don't import between feature modules — go through `core/` or root-level providers.
- Don't create OOP abstractions or framework patterns in PHP (keep procedural).
- Don't use `{"success": true/false}` in API responses — use `{"status": "success/error"}`.
- Don't hardcode user-facing strings without translation entries.
- Don't store files outside the `uploads/` directory.
- Don't use `DropdownButtonFormField` — use `DropdownMenu` (M3).
- Don't hardcode colors in widgets — use theme system.
- Don't store absolute image URLs with IPs in database — store relative paths.
- Don't trust client-sent `user_id` — extract from JWT.
- Don't leave dead code (remove unused dependencies, files, endpoints).
- Don't use PDO methods with mysqli connection.
- Don't skip input validation on API endpoints.
- Don't use glassmorphism.
- Don't use outdated widget, use latest material 3 widgets.
- Don't do SLOP.
---

## 13. Development Environment

| Tool | Details |
|---|---|
| **IDE** | VS Code |
| **Flutter SDK** | `^3.11.0` |
| **Dart SDK** | Bundled with Flutter |
| **PHP** | 8.x via XAMPP |
| **Database** | MariaDB 10.4.32 via XAMPP |
| **Database Name** | `srs_db` |
| **Web Server** | Apache via XAMPP |
| **API Path** | `c:\xampp\htdocs\srs_api\` |
| **App Path** | `c:\Users\rafee\Documents\UTeM\FYP\srs_app\` |
| **FYP Root** | `c:\Users\rafee\Documents\UTeM\FYP\` |
| **Schema SQL** | `c:\Users\rafee\Documents\UTeM\FYP\srs_db.sql` |
| **Testing Devices** | Android physical device (USB debug) + Chrome web |
| **Emulator Base URL** | `http://10.0.2.2/srs_api/` (Android emulator → local XAMPP) |
| **Current Base URL** | `http://10.131.77.105/srs_api/` (specific machine IP) |
