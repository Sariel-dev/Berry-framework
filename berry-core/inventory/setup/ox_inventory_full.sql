-- ox_inventory full schema (core + custom modules in this server)
-- Generated on 2026-02-13

-- ===============================
-- CORE OX_INVENTORY
-- ===============================
CREATE TABLE IF NOT EXISTS `ox_inventory` (
  `owner` varchar(60) DEFAULT NULL,
  `name` varchar(100) NOT NULL,
  `data` longtext DEFAULT NULL,
  `lastupdated` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  UNIQUE KEY `owner` (`owner`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ox_inventory_placed_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `owner` varchar(60) NOT NULL,
  `item_name` varchar(100) NOT NULL,
  `prop_model` varchar(100) NOT NULL,
  `coords_x` float NOT NULL,
  `coords_y` float NOT NULL,
  `coords_z` float NOT NULL,
  `heading` float NOT NULL,
  `slot` int(11) NOT NULL,
  `metadata` longtext DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ox_inventory_clothing` (
  `owner` varchar(100) NOT NULL,
  `slots` longtext DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===============================
-- LOCKERS / CASIERS (custom)
-- ===============================
CREATE TABLE IF NOT EXISTS `ox_inventory_lockers` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `coords_x` FLOAT NOT NULL,
  `coords_y` FLOAT NOT NULL,
  `coords_z` FLOAT NOT NULL,
  `label` VARCHAR(255),
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ox_inventory_locker_casiers` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `locker_id` INT NOT NULL,
  `casier_number` INT NOT NULL,
  `label` VARCHAR(255),
  `pin_code` VARCHAR(4) NULL,
  `note` TEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_ox_inv_locker_casier_locker`
    FOREIGN KEY (`locker_id`) REFERENCES `ox_inventory_lockers`(`id`) ON DELETE CASCADE,
  UNIQUE KEY `unique_casier` (`locker_id`, `casier_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===============================
-- MULTICHEST (custom)
-- ===============================
CREATE TABLE IF NOT EXISTS `ox_inventory_multichests` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `coords_x` FLOAT NOT NULL,
  `coords_y` FLOAT NOT NULL,
  `coords_z` FLOAT NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ox_inventory_multichest_lockers` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `multichest_id` INT NOT NULL,
  `locker_number` INT NOT NULL,
  `label` VARCHAR(255),
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_ox_inv_multichest_locker_parent`
    FOREIGN KEY (`multichest_id`) REFERENCES `ox_inventory_multichests`(`id`) ON DELETE CASCADE,
  UNIQUE KEY `unique_locker` (`multichest_id`, `locker_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===============================
-- FRAMEWORK ALTERS (ESX)
-- ===============================
ALTER TABLE `owned_vehicles` ADD COLUMN IF NOT EXISTS `glovebox` LONGTEXT NULL;
ALTER TABLE `owned_vehicles` ADD COLUMN IF NOT EXISTS `trunk` LONGTEXT NULL;
ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `inventory` LONGTEXT NULL;

-- ===============================
-- OPTIONAL LPF1 CRAFTING TABLE
-- ===============================
CREATE TABLE IF NOT EXISTS `ox_inventory_crafting` (
  `id` VARCHAR(64) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
