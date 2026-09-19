-- iRonda schema only; source: September 2, 2026 snapshot used for cPanel recovery.
-- Import into a NEW empty database. No account records or uploads are included.
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS=0;

CREATE TABLE `attendance` (
  `id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `state_id` varchar(36) DEFAULT NULL,
  `district_id` varchar(36) DEFAULT NULL,
  `zone_id` varchar(36) DEFAULT NULL,
  `schedule_id` varchar(36) DEFAULT NULL,
  `checkpoint_id` varchar(255) DEFAULT NULL,
  `latitude` varchar(50) DEFAULT NULL,
  `longitude` varchar(50) DEFAULT NULL,
  `clock_in_time` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `clock_out_time` timestamp NULL DEFAULT NULL,
  `clock_out_latitude` varchar(50) DEFAULT NULL,
  `clock_out_longitude` varchar(50) DEFAULT NULL,
  `return_status` enum('active','pending_acknowledgement','completed','equipment_exception') NOT NULL DEFAULT 'active',
  `return_requested_at` timestamp NULL DEFAULT NULL,
  `return_checkpoint_id` varchar(255) DEFAULT NULL,
  `return_latitude` varchar(50) DEFAULT NULL,
  `return_longitude` varchar(50) DEFAULT NULL,
  `return_acknowledged_at` timestamp NULL DEFAULT NULL,
  `return_acknowledged_by` varchar(36) DEFAULT NULL,
  `return_exception_reason` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `fk_schedule` (`schedule_id`),
  KEY `idx_attendance_location_created` (`state_id`,`district_id`,`zone_id`,`created_at`),
  KEY `fk_attendance_district` (`district_id`),
  KEY `fk_attendance_zone` (`zone_id`),
  CONSTRAINT `attendance_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_attendance_district` FOREIGN KEY (`district_id`) REFERENCES `districts` (`id`),
  CONSTRAINT `fk_attendance_state` FOREIGN KEY (`state_id`) REFERENCES `states` (`id`),
  CONSTRAINT `fk_attendance_zone` FOREIGN KEY (`zone_id`) REFERENCES `zones` (`id`),
  CONSTRAINT `fk_schedule` FOREIGN KEY (`schedule_id`) REFERENCES `schedules` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `attendance_assessments` (
  `id` varchar(36) NOT NULL,
  `schedule_id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `assessed_by` varchar(36) NOT NULL,
  `status` enum('present','late','absent','excused') NOT NULL DEFAULT 'present',
  `notes` varchar(500) DEFAULT NULL,
  `acknowledged_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_attendance_assessment_schedule_user` (`schedule_id`,`user_id`),
  KEY `idx_attendance_assessments_assessed_by` (`assessed_by`),
  KEY `idx_attendance_assessments_status` (`status`),
  KEY `fk_attendance_assessments_user` (`user_id`),
  CONSTRAINT `fk_attendance_assessments_assessor` FOREIGN KEY (`assessed_by`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_attendance_assessments_schedule` FOREIGN KEY (`schedule_id`) REFERENCES `schedules` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_attendance_assessments_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `districts` (
  `id` varchar(36) NOT NULL,
  `state_id` varchar(36) NOT NULL,
  `name` varchar(100) NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_districts_state_name` (`state_id`,`name`),
  KEY `idx_districts_state_id` (`state_id`),
  CONSTRAINT `fk_districts_state` FOREIGN KEY (`state_id`) REFERENCES `states` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `equipment_inventory` (
  `id` varchar(36) NOT NULL,
  `item_name` varchar(100) NOT NULL,
  `total_quantity` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `equipment_logs` (
  `id` varchar(36) NOT NULL,
  `attendance_id` varchar(36) NOT NULL,
  `equipment_id` varchar(36) NOT NULL,
  `borrowed_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `returned_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `attendance_id` (`attendance_id`),
  KEY `equipment_id` (`equipment_id`),
  CONSTRAINT `equipment_logs_ibfk_1` FOREIGN KEY (`attendance_id`) REFERENCES `attendance` (`id`) ON DELETE CASCADE,
  CONSTRAINT `equipment_logs_ibfk_2` FOREIGN KEY (`equipment_id`) REFERENCES `equipment_inventory` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `incidents` (
  `id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `state_id` varchar(36) DEFAULT NULL,
  `district_id` varchar(36) DEFAULT NULL,
  `zone_id` varchar(36) DEFAULT NULL,
  `title` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `category` varchar(50) NOT NULL,
  `image_url` text DEFAULT NULL,
  `latitude` varchar(50) NOT NULL,
  `longitude` varchar(50) NOT NULL,
  `status` varchar(20) DEFAULT 'Pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `location_name` varchar(255) DEFAULT NULL,
  `reported_to` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `idx_incidents_location_created` (`state_id`,`district_id`,`zone_id`,`created_at`),
  KEY `fk_incidents_district` (`district_id`),
  KEY `fk_incidents_zone` (`zone_id`),
  CONSTRAINT `fk_incidents_district` FOREIGN KEY (`district_id`) REFERENCES `districts` (`id`),
  CONSTRAINT `fk_incidents_state` FOREIGN KEY (`state_id`) REFERENCES `states` (`id`),
  CONSTRAINT `fk_incidents_zone` FOREIGN KEY (`zone_id`) REFERENCES `zones` (`id`),
  CONSTRAINT `incidents_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `notifications` (
  `id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `actor_user_id` varchar(36) DEFAULT NULL,
  `type` varchar(50) NOT NULL,
  `title` varchar(150) NOT NULL,
  `body` varchar(500) NOT NULL,
  `payload_json` longtext DEFAULT NULL,
  `is_read` tinyint(1) NOT NULL DEFAULT 0,
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `read_at` timestamp NULL DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_notifications_user_unread` (`user_id`,`is_read`,`created_at`),
  KEY `fk_notifications_actor` (`actor_user_id`),
  KEY `idx_notifications_user_deleted_read` (`user_id`,`is_deleted`,`is_read`,`created_at`),
  CONSTRAINT `fk_notifications_actor` FOREIGN KEY (`actor_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_notifications_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `registration_request_limits` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `endpoint` varchar(50) NOT NULL,
  `client_hash` char(64) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_registration_request_limit` (`endpoint`,`client_hash`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `registration_verifications` (
  `id` varchar(36) NOT NULL,
  `token_hash` char(64) NOT NULL,
  `ic_hash` char(64) NOT NULL,
  `device_hash` char(64) NOT NULL,
  `ip_hash` char(64) NOT NULL,
  `full_name` varchar(100) DEFAULT NULL,
  `state_id` varchar(36) DEFAULT NULL,
  `status` enum('started','verified','failed','consumed','expired') NOT NULL DEFAULT 'started',
  `failure_reason` varchar(50) DEFAULT NULL,
  `verification_method` varchar(50) DEFAULT NULL,
  `model_version` varchar(50) DEFAULT NULL,
  `similarity_score` decimal(5,4) DEFAULT NULL,
  `liveness_passed` tinyint(1) NOT NULL DEFAULT 0,
  `quality_passed` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `expires_at` datetime NOT NULL,
  `verified_at` datetime DEFAULT NULL,
  `consumed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_registration_verification_token` (`token_hash`),
  KEY `idx_registration_verification_ic_status` (`ic_hash`,`status`,`created_at`),
  KEY `idx_registration_verification_device_status` (`device_hash`,`status`,`created_at`),
  KEY `idx_registration_verification_ip_status` (`ip_hash`,`status`,`created_at`),
  KEY `idx_registration_verification_expiry` (`expires_at`),
  KEY `fk_registration_verification_state_20260808` (`state_id`),
  CONSTRAINT `fk_registration_verification_state_20260808` FOREIGN KEY (`state_id`) REFERENCES `states` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `schedules` (
  `id` varchar(36) NOT NULL,
  `squad_id` varchar(36) NOT NULL,
  `state_id` varchar(36) DEFAULT NULL,
  `district_id` varchar(36) DEFAULT NULL,
  `zone_id` varchar(36) DEFAULT NULL,
  `shift_date` date NOT NULL,
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `squad_id` (`squad_id`),
  KEY `idx_schedules_location_date` (`state_id`,`district_id`,`zone_id`,`shift_date`),
  KEY `idx_schedules_district_id` (`district_id`),
  KEY `idx_schedules_zone_id` (`zone_id`),
  CONSTRAINT `fk_schedules_district` FOREIGN KEY (`district_id`) REFERENCES `districts` (`id`),
  CONSTRAINT `fk_schedules_state` FOREIGN KEY (`state_id`) REFERENCES `states` (`id`),
  CONSTRAINT `fk_schedules_zone` FOREIGN KEY (`zone_id`) REFERENCES `zones` (`id`),
  CONSTRAINT `schedules_ibfk_1` FOREIGN KEY (`squad_id`) REFERENCES `squads` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `sos_acknowledgements` (
  `id` varchar(36) NOT NULL,
  `incident_id` varchar(36) NOT NULL,
  `receiver_user_id` varchar(36) NOT NULL,
  `acknowledged_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sos_acknowledgements_receiver` (`incident_id`,`receiver_user_id`),
  KEY `idx_sos_acknowledgements_receiver` (`receiver_user_id`,`acknowledged_at`),
  CONSTRAINT `fk_sos_acknowledgements_incident` FOREIGN KEY (`incident_id`) REFERENCES `incidents` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_sos_acknowledgements_receiver` FOREIGN KEY (`receiver_user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `squad_members` (
  `squad_id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `role` enum('leader','member') DEFAULT 'member',
  PRIMARY KEY (`squad_id`,`user_id`),
  UNIQUE KEY `uq_squad_members_user` (`user_id`),
  CONSTRAINT `squad_members_ibfk_1` FOREIGN KEY (`squad_id`) REFERENCES `squads` (`id`) ON DELETE CASCADE,
  CONSTRAINT `squad_members_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `squads` (
  `id` varchar(36) NOT NULL,
  `name` varchar(100) NOT NULL,
  `state_id` varchar(36) DEFAULT NULL,
  `district_id` varchar(36) DEFAULT NULL,
  `zone_id` varchar(36) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_squads_state_id` (`state_id`),
  KEY `idx_squads_district_id` (`district_id`),
  KEY `idx_squads_zone_id` (`zone_id`),
  CONSTRAINT `fk_squads_district` FOREIGN KEY (`district_id`) REFERENCES `districts` (`id`),
  CONSTRAINT `fk_squads_state` FOREIGN KEY (`state_id`) REFERENCES `states` (`id`),
  CONSTRAINT `fk_squads_zone` FOREIGN KEY (`zone_id`) REFERENCES `zones` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `states` (
  `id` varchar(36) NOT NULL,
  `code` varchar(10) NOT NULL,
  `name` varchar(100) NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_states_code` (`code`),
  UNIQUE KEY `uq_states_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `users` (
  `id` varchar(36) NOT NULL,
  `full_name` varchar(100) NOT NULL,
  `ic_number` varchar(20) NOT NULL,
  `phone_number` varchar(15) NOT NULL,
  `email` varchar(100) NOT NULL,
  `profile_image_path` varchar(255) DEFAULT NULL,
  `password_hash` varchar(255) NOT NULL,
  `district_zone` varchar(50) NOT NULL,
  `state_id` varchar(36) DEFAULT NULL,
  `district_id` varchar(36) DEFAULT NULL,
  `zone_id` varchar(36) DEFAULT NULL,
  `role` enum('peronda','ketua_peronda','ketua_krt','super_admin') NOT NULL DEFAULT 'peronda',
  `account_status` enum('pending','active','inactive') DEFAULT 'pending',
  `profile_image_url` text DEFAULT NULL,
  `must_change_password` tinyint(1) NOT NULL DEFAULT 0,
  `identity_verification_status` enum('legacy','verified','not_verified') NOT NULL DEFAULT 'legacy',
  `identity_verification_method` varchar(50) DEFAULT NULL,
  `identity_verified_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `ic_number` (`ic_number`),
  UNIQUE KEY `email` (`email`),
  KEY `idx_users_state_id` (`state_id`),
  KEY `idx_users_district_id` (`district_id`),
  KEY `idx_users_zone_id` (`zone_id`),
  CONSTRAINT `fk_users_district` FOREIGN KEY (`district_id`) REFERENCES `districts` (`id`),
  CONSTRAINT `fk_users_state` FOREIGN KEY (`state_id`) REFERENCES `states` (`id`),
  CONSTRAINT `fk_users_zone` FOREIGN KEY (`zone_id`) REFERENCES `zones` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `zones` (
  `id` varchar(36) NOT NULL,
  `district_id` varchar(36) NOT NULL,
  `name` varchar(100) NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_zones_district_name` (`district_id`,`name`),
  KEY `idx_zones_district_id` (`district_id`),
  CONSTRAINT `fk_zones_district` FOREIGN KEY (`district_id`) REFERENCES `districts` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

SET FOREIGN_KEY_CHECKS=1;
