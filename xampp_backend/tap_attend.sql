CREATE DATABASE IF NOT EXISTS `tap_attend` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `tap_attend`;

-- Table for students
CREATE TABLE IF NOT EXISTS `students` (
  `id` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `card_uid` VARCHAR(50) NOT NULL,
  `subject_code` VARCHAR(50) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `card_uid_unique` (`card_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table for class sessions
CREATE TABLE IF NOT EXISTS `sessions` (
  `session_id` VARCHAR(50) NOT NULL,
  `subject_code` VARCHAR(50) NOT NULL,
  `subject_name` VARCHAR(150) NOT NULL,
  `room` VARCHAR(50) NOT NULL,
  `start_time` DATETIME NOT NULL,
  `end_time` DATETIME NOT NULL,
  `total_enrolled` INT NOT NULL,
  `present_count` INT NOT NULL,
  PRIMARY KEY (`session_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table for attendance records
CREATE TABLE IF NOT EXISTS `attendance` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `session_id` VARCHAR(50) NOT NULL,
  `student_id` VARCHAR(50) NOT NULL,
  `student_name` VARCHAR(100) NOT NULL,
  `card_uid` VARCHAR(50) NOT NULL,
  `scan_time` DATETIME NOT NULL,
  FOREIGN KEY (`session_id`) REFERENCES `sessions` (`session_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
