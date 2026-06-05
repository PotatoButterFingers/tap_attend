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

-- Seed default students for classes
INSERT INTO `students` (`id`, `name`, `card_uid`, `subject_code`) VALUES
('101', 'Benjamin Miller', 'tag_1', 'CS101'),
('102', 'Sophia Chen', 'tag_2', 'CS101'),
('103', 'Marcus Wright', 'tag_3', 'CS101'),
('201', 'Emma Watson', 'tag_4', 'CS202'),
('202', 'Liam Neeson', 'tag_5', 'CS202'),
('203', 'Olivia Wilde', 'tag_6', 'CS202'),
('301', 'Noah Centineo', 'tag_7', 'CS303'),
('302', 'Ava DuVernay', 'tag_8', 'CS303'),
('303', 'Lucas Hedges', 'tag_9', 'CS303')
ON DUPLICATE KEY UPDATE name=VALUES(name), card_uid=VALUES(card_uid), subject_code=VALUES(subject_code);

-- Table for lecturers
CREATE TABLE IF NOT EXISTS `lecturers` (
  `lecturer_id` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `email` VARCHAR(100) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `card_uid` VARCHAR(50) NULL UNIQUE,
  `department` VARCHAR(100) NOT NULL,
  `office` VARCHAR(100) NOT NULL,
  `phone` VARCHAR(30) NOT NULL,
  PRIMARY KEY (`lecturer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed default lecturer
INSERT INTO `lecturers` (`lecturer_id`, `name`, `email`, `password_hash`, `card_uid`, `department`, `office`, `phone`) VALUES
('sharvin', 'Mr. Sharvin Ganeson', 'sharvin.ganeson@university.edu', '$2y$10$FKSqrtsFxfGr9PuAdtb.wu4zdIh2.uE/sToclxoNGjU/a29IPdiPu', 'lecturer_card_1', 'Dept. of Computer Science', 'Engineering Bldg, Room 402', '+1 (555) 123-4567')
ON DUPLICATE KEY UPDATE name=VALUES(name), email=VALUES(email), password_hash=VALUES(password_hash), card_uid=VALUES(card_uid), department=VALUES(department), office=VALUES(office), phone=VALUES(phone);


