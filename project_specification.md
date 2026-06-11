# SRS Patrol System - Project Specification & Architecture

## Overview
The SRS (Skim Rondaan Sukarela) Patrol System is a comprehensive, multi-platform digital solution designed to modernize the management and operations of Rukun Tetangga (KRT) volunteer patrols in Malaysia. It bridges the gap between field patrollers and the main command center by digitizing attendance, incident reporting, and SOS emergencies.

## Core Technologies
*   **Frontend Mobile & Web:** Flutter (Dart) using Provider for State Management.
*   **Backend API:** Raw PHP 8 (Procedural) handling JSON endpoints.
*   **Database:** MySQL (MariaDB via XAMPP) using `srs_db`.
*   **Local Storage:** `shared_preferences` for session caching.
*   **Key Packages:** `geocoding`, `geolocator`, `fl_chart`, `qr_flutter`, `mobile_scanner`, `image_picker`.

## 3-Tier Role Architecture
The system enforces strict Role-Based Access Control (RBAC) separating users into three distinct tiers:

### 1. Peronda (Normal Patroller)
*   **Role ID:** `peronda`
*   **Platform:** Mobile App
*   **Core Functions:**
    *   **QR Attendance:** Scans a physical/digital QR code at the Main Post to clock in/out of a shift. Enforces GPS geofencing to prevent spoofing.
    *   **SOS Emergency:** A panic button that instantly broadcasts their live GPS coordinates and triggers a loud siren UI on the command center's end.
    *   **Incident Reporting:** Can capture photos, categorize (e.g., *Jenayah Kekerasan, Vandalism*), and submit reports.
    *   **Feed:** Views a global scrolling feed of recent incidents.

### 2. Ketua Peronda (Head Patroller / Squad Leader)
*   **Role ID:** `ketua_peronda`
*   **Platform:** Mobile App
*   **Core Functions:**
    *   Inherits all capabilities of the `peronda` (Reporting, SOS, Scanning).
    *   **Organized Folder View (Laporan):** Instead of a raw global feed, they access a structured directory of their squad members. They can filter by Zone, search by Name, tap on a specific Patroller's card, and view *only* the incidents submitted by that individual.

### 3. Admin KRT (Command Center / Main Post)
*   **Role ID:** `ketua_krt`
*   **Platform:** Dual-Platform (Web Dashboard & Mobile App)
*   **Core Functions:**
    *   **QR Generation (Mobile):** The Admin uses their phone to generate the Shift QR Code. The app reverse-geocodes their current GPS location into a District Name and embeds a secure token into the QR code for patrollers to scan.
    *   **Live Tracking (Web/Mobile):** Monitors active shifts and live movements of patrollers.
    *   **Analytics (Web/Mobile):** Views data visualization (`fl_chart`) regarding patrol frequency, incident severity, and monthly statistics.
    *   **Member Management:** Manages the roster of volunteers. *Note: In accordance with JPNIN RT 01 SOP, volunteers must physically visit the post to fill out official documents before they can patrol. The app serves as a digital registry for their active/inactive status following the paperwork approval.*

## Database Schema Highlights (`srs_db`)

### 1. `users` Table
*   `id` (UUID), `full_name`, `ic_number`, `district_zone`, `phone_number`, `email`, `password_hash`.
*   `role` (ENUM: `peronda`, `ketua_peronda`, `ketua_krt`).
*   `account_status` (ENUM: `pending`, `active`, `inactive`).

### 2. `attendance` Table
*   `id` (UUID), `user_id`, `check_in_time`, `check_out_time`, `shift_duration`.
*   `gps_lat`, `gps_lng` (Validated against the generated QR token).

### 3. `incidents` Table
*   `id` (UUID), `user_id`, `title`, `description`, `category`.
*   `image_url` (JSON array of uploaded file paths).
*   `latitude`, `longitude`, `created_at`.

## Routing Logic (`lib/main.dart`)
The app utilizes a `RootRouter` widget wrapped in a `Consumer<AuthProvider>`.
*   If `authProvider.isAuthenticated` is false, it returns `LoginScreen`.
*   If `authProvider.role == 'ketua_krt'`, it evaluates screen width to return `WebDashboardLayout` (Desktop) or `AdminMobileLayout` (Phone).
*   If `authProvider.role == 'ketua_peronda'`, it returns `KetuaMobileLayout`.
*   If `authProvider.role == 'peronda'`, it returns `MainShell`.

## Security & Validation
*   **Anti-Cheat QR:** QR codes contain temporal tokens and GPS anchors.
*   **Bcrypt Hashing:** All passwords are mathematically hashed via PHP's `password_hash()`.
*   **Session Management:** `SharedPreferences` securely caches `user_id` and `user_role`. Upon explicitly logging out, memory is wiped to force re-evaluation of routing.
