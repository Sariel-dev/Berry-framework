-- Migration 001: Initial Berry Framework Database Schema

CREATE TABLE IF NOT EXISTS `berry_accounts` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `identifier` VARCHAR(100) NOT NULL UNIQUE,
  `license` VARCHAR(100) NULL,
  `discord` VARCHAR(100) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_identifier` (`identifier`),
  INDEX `idx_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_characters` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `account_id` INT NOT NULL,
  `firstname` VARCHAR(50) NOT NULL,
  `lastname` VARCHAR(50) NOT NULL,
  `dateofbirth` VARCHAR(20) NOT NULL,
  `sex` VARCHAR(10) NOT NULL DEFAULT 'm',
  `position` LONGTEXT NULL,
  `metadata` LONGTEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_berry_char_account` FOREIGN KEY (`account_id`) REFERENCES `berry_accounts`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_character_data` (
  `character_id` INT NOT NULL,
  `data_key` VARCHAR(50) NOT NULL,
  `data_value` LONGTEXT NULL,
  PRIMARY KEY (`character_id`, `data_key`),
  CONSTRAINT `fk_berry_chardata_char` FOREIGN KEY (`character_id`) REFERENCES `berry_characters`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_economy_accounts` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `owner_type` ENUM('character', 'organization', 'system') NOT NULL,
  `owner_id` VARCHAR(100) NOT NULL,
  `account_type` VARCHAR(50) NOT NULL,
  `balance` DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  UNIQUE KEY `uk_owner_account` (`owner_type`, `owner_id`, `account_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_inventories` (
  `id` VARCHAR(100) PRIMARY KEY,
  `owner_type` ENUM('character', 'vehicle', 'property', 'drop') NOT NULL,
  `owner_id` VARCHAR(100) NOT NULL,
  `max_weight` INT NOT NULL DEFAULT 30000,
  `max_slots` INT NOT NULL DEFAULT 50
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_inventory_items` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `inventory_id` VARCHAR(100) NOT NULL,
  `slot` INT NOT NULL,
  `item_name` VARCHAR(50) NOT NULL,
  `count` INT NOT NULL DEFAULT 1,
  `metadata` LONGTEXT NULL,
  CONSTRAINT `fk_berry_inv_items` FOREIGN KEY (`inventory_id`) REFERENCES `berry_inventories`(`id`) ON DELETE CASCADE,
  INDEX `idx_inv_slot` (`inventory_id`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_items` (
  `name` VARCHAR(50) PRIMARY KEY,
  `label` VARCHAR(100) NOT NULL,
  `weight` INT NOT NULL DEFAULT 100,
  `stackable` TINYINT(1) NOT NULL DEFAULT 1,
  `usable` TINYINT(1) NOT NULL DEFAULT 0,
  `description` TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_jobs` (
  `name` VARCHAR(50) PRIMARY KEY,
  `label` VARCHAR(100) NOT NULL,
  `whitelisted` TINYINT(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_job_grades` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `job_name` VARCHAR(50) NOT NULL,
  `grade` INT NOT NULL,
  `name` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `salary` INT NOT NULL DEFAULT 200,
  `permissions` LONGTEXT NULL,
  CONSTRAINT `fk_berry_job_grade` FOREIGN KEY (`job_name`) REFERENCES `berry_jobs`(`name`) ON DELETE CASCADE,
  UNIQUE KEY `uk_job_grade` (`job_name`, `grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_organizations` (
  `id` VARCHAR(50) PRIMARY KEY,
  `label` VARCHAR(100) NOT NULL,
  `type` VARCHAR(50) NOT NULL DEFAULT 'gang',
  `balance` DECIMAL(15,2) NOT NULL DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_organization_members` (
  `organization_id` VARCHAR(50) NOT NULL,
  `character_id` INT NOT NULL,
  `grade` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`organization_id`, `character_id`),
  CONSTRAINT `fk_berry_org_id` FOREIGN KEY (`organization_id`) REFERENCES `berry_organizations`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_berry_org_char` FOREIGN KEY (`character_id`) REFERENCES `berry_characters`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_vehicles` (
  `plate` VARCHAR(12) PRIMARY KEY,
  `owner_id` INT NOT NULL,
  `model` VARCHAR(50) NOT NULL,
  `vehicle_data` LONGTEXT NULL,
  `garage` VARCHAR(50) DEFAULT 'pillbox',
  `state` INT DEFAULT 1,
  CONSTRAINT `fk_berry_veh_char` FOREIGN KEY (`owner_id`) REFERENCES `berry_characters`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_properties` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(100) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `owner_id` INT NULL,
  `price` INT NOT NULL DEFAULT 100000,
  `is_locked` TINYINT(1) NOT NULL DEFAULT 1,
  `storage_id` VARCHAR(100) NULL,
  `ipl` VARCHAR(100) DEFAULT 'apa_v_mp_h_01_a',
  `entry_coords` LONGTEXT NULL,
  `exit_coords` LONGTEXT NULL,
  `storage_coords` LONGTEXT NULL,
  CONSTRAINT `fk_berry_prop_char` FOREIGN KEY (`owner_id`) REFERENCES `berry_characters`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_transactions` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `source_id` VARCHAR(100) NOT NULL,
  `target_id` VARCHAR(100) NOT NULL,
  `amount` DECIMAL(15,2) NOT NULL,
  `account_type` VARCHAR(50) NOT NULL,
  `reason` VARCHAR(255) NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_bans` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `target_identifier` VARCHAR(100) NOT NULL,
  `target_name` VARCHAR(100) NOT NULL,
  `author_name` VARCHAR(100) NOT NULL,
  `reason` TEXT NOT NULL,
  `expiration` TIMESTAMP NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `berry_warnings` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `target_identifier` VARCHAR(100) NOT NULL,
  `author_name` VARCHAR(100) NOT NULL,
  `reason` TEXT NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
