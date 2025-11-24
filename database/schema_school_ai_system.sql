-- Create database
CREATE DATABASE IF NOT EXISTS school_ai_system;
USE school_ai_system;

-- ============================================
-- TABLE 1: Students
-- ============================================
CREATE TABLE IF NOT EXISTS students (
  student_id INT AUTO_INCREMENT PRIMARY KEY,
  student_name VARCHAR(100) NOT NULL,
  class VARCHAR(10) NOT NULL,
  section VARCHAR(5) NOT NULL,
  roll_no INT NOT NULL,
  gender VARCHAR(10),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLE 2: Teachers
-- ============================================
CREATE TABLE IF NOT EXISTS teachers (
  teacher_id INT AUTO_INCREMENT PRIMARY KEY,
  teacher_name VARCHAR(100) NOT NULL,
  SUBJECT VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLE 3: Subjects
-- ============================================
CREATE TABLE IF NOT EXISTS subjects (
  subject_id INT AUTO_INCREMENT PRIMARY KEY,
  subject_name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLE 4: Exams
-- ============================================
CREATE TABLE IF NOT EXISTS exams (
  exam_id INT AUTO_INCREMENT PRIMARY KEY,
  exam_name VARCHAR(100) NOT NULL,
  class VARCHAR(10) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLE 5: Marks
-- ============================================
CREATE TABLE IF NOT EXISTS marks (
  mark_id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  exam_id INT NOT NULL,
  total_marks DECIMAL(5,2) NOT NULL,
  obtained_marks DECIMAL(5,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (student_id) REFERENCES students(student_id),
  FOREIGN KEY (exam_id) REFERENCES exams(exam_id)
);

-- ============================================
-- TABLE 6: Attendance
-- ============================================
CREATE TABLE IF NOT EXISTS attendance (
  attendance_id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  total_days INT NOT NULL DEFAULT 0,
  present_days INT NOT NULL DEFAULT 0,
  absent_days INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (student_id) REFERENCES students(student_id)
);

-- ============================================
-- TABLE 7: Fees
-- ============================================
CREATE TABLE IF NOT EXISTS fees (
  fee_id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  total_fee DECIMAL(10,2) NOT NULL,
  paid_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
  due_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (student_id) REFERENCES students(student_id)
);

-- ============================================
-- TABLE 8: Rankings
-- ============================================
CREATE TABLE IF NOT EXISTS rankings (
  rank_id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  class_rank INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (student_id) REFERENCES students(student_id)
);

-- ============================================
-- TABLE 9: Leave Records
-- ============================================
CREATE TABLE IF NOT EXISTS leave_records (
  leave_id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  leave_type VARCHAR(50) NOT NULL,
  leave_days INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (student_id) REFERENCES students(student_id)
);

-- ============================================
-- TABLE 10: Class Summary
-- ============================================
CREATE TABLE IF NOT EXISTS class_summary (
  summary_id INT AUTO_INCREMENT PRIMARY KEY,
  class VARCHAR(10) NOT NULL,
  section VARCHAR(5) NOT NULL,
  total_students INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLE 11: Search History (for chatbot)
-- ============================================
CREATE TABLE IF NOT EXISTS search_history (
  id INT AUTO_INCREMENT PRIMARY KEY,
  question TEXT NOT NULL,
  generated_sql TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- INSERT DATA: 100 Students
-- ============================================
INSERT INTO students (student_name, class, section, roll_no, gender) VALUES
('Aarav Patel', '10', 'A', 1, 'Male'),
('Aanya Sharma', '10', 'A', 2, 'Female'),
('Aditya Kumar', '10', 'A', 3, 'Male'),
('Ananya Singh', '10', 'A', 4, 'Female'),
('Arjun Verma', '10', 'A', 5, 'Male'),
('Avni Gupta', '10', 'B', 1, 'Female'),
('Devansh Mehta', '10', 'B', 2, 'Male'),
('Diya Patel', '10', 'B', 3, 'Female'),
('Ishaan Shah', '10', 'B', 4, 'Male'),
('Kavya Reddy', '10', 'B', 5, 'Female'),
('Rohan Desai', '10', 'C', 1, 'Male'),
('Saanvi Joshi', '10', 'C', 2, 'Female'),
('Vihaan Agarwal', '10', 'C', 3, 'Male'),
('Zara Khan', '10', 'C', 4, 'Female'),
('Aryan Malhotra', '10', 'C', 5, 'Male'),
('Ishita Nair', '9', 'A', 1, 'Female'),
('Kabir Kapoor', '9', 'A', 2, 'Male'),
('Maya Iyer', '9', 'A', 3, 'Female'),
('Neel Menon', '9', 'A', 4, 'Male'),
('Pooja Rao', '9', 'A', 5, 'Female'),
('Rahul Nair', '9', 'B', 1, 'Male'),
('Riya Krishnan', '9', 'B', 2, 'Female'),
('Samarth Pillai', '9', 'B', 3, 'Male'),
('Tara Subramanian', '9', 'B', 4, 'Female'),
('Vedant Warrier', '9', 'B', 5, 'Male'),
('Yashasvi Nambiar', '9', 'C', 1, 'Female'),
('Akshay Menon', '9', 'C', 2, 'Male'),
('Bhavya Nair', '9', 'C', 3, 'Female'),
('Chaitanya Pillai', '9', 'C', 4, 'Male'),
('Darshana Iyer', '9', 'C', 5, 'Female'),
('Eshaan Nambiar', '11', 'A', 1, 'Male'),
('Falguni Warrier', '11', 'A', 2, 'Female'),
('Gaurav Subramanian', '11', 'A', 3, 'Male'),
('Harshita Krishnan', '11', 'A', 4, 'Female'),
('Indrajeet Rao', '11', 'A', 5, 'Male'),
('Jhanvi Kapoor', '11', 'B', 1, 'Female'),
('Karan Iyer', '11', 'B', 2, 'Male'),
('Lavanya Menon', '11', 'B', 3, 'Female'),
('Manav Pillai', '11', 'B', 4, 'Male'),
('Nandini Nair', '11', 'B', 5, 'Female'),
('Omkar Warrier', '11', 'C', 1, 'Male'),
('Pranavi Subramanian', '11', 'C', 2, 'Female'),
('Quresh Krishnan', '11', 'C', 3, 'Male'),
('Radhika Rao', '11', 'C', 4, 'Female'),
('Siddharth Kapoor', '11', 'C', 5, 'Male'),
('Tanvi Iyer', '12', 'A', 1, 'Female'),
('Uday Menon', '12', 'A', 2, 'Male'),
('Vaishnavi Pillai', '12', 'A', 3, 'Female'),
('Waseem Nair', '12', 'A', 4, 'Male'),
('Xara Warrier', '12', 'A', 5, 'Female'),
('Yuvraj Subramanian', '12', 'B', 1, 'Male'),
('Zara Krishnan', '12', 'B', 2, 'Female'),
('Aaditya Rao', '12', 'B', 3, 'Male'),
('Bhumika Kapoor', '12', 'B', 4, 'Female'),
('Chirag Iyer', '12', 'B', 5, 'Male'),
('Disha Menon', '12', 'C', 1, 'Female'),
('Eshan Pillai', '12', 'C', 2, 'Male'),
('Fatima Nair', '12', 'C', 3, 'Female'),
('Ganesh Warrier', '12', 'C', 4, 'Male'),
('Hema Subramanian', '12', 'C', 5, 'Female'),
('Ishan Krishnan', '8', 'A', 1, 'Male'),
('Jiya Rao', '8', 'A', 2, 'Female'),
('Kartik Kapoor', '8', 'A', 3, 'Male'),
('Lakshmi Iyer', '8', 'A', 4, 'Female'),
('Mohit Menon', '8', 'A', 5, 'Male'),
('Nisha Pillai', '8', 'B', 1, 'Female'),
('Om Nair', '8', 'B', 2, 'Male'),
('Priya Warrier', '8', 'B', 3, 'Female'),
('Ravi Subramanian', '8', 'B', 4, 'Male'),
('Sneha Krishnan', '8', 'B', 5, 'Female'),
('Tarun Rao', '8', 'C', 1, 'Male'),
('Uma Kapoor', '8', 'C', 2, 'Female'),
('Varun Iyer', '8', 'C', 3, 'Male'),
('Wendy Menon', '8', 'C', 4, 'Female'),
('Xavier Pillai', '8', 'C', 5, 'Male'),
('Yamini Nair', '7', 'A', 1, 'Female'),
('Zain Warrier', '7', 'A', 2, 'Male'),
('Aaliyah Subramanian', '7', 'A', 3, 'Female'),
('Benjamin Krishnan', '7', 'A', 4, 'Male'),
('Chloe Rao', '7', 'A', 5, 'Female'),
('Daniel Kapoor', '7', 'B', 1, 'Male'),
('Emma Iyer', '7', 'B', 2, 'Female'),
('Finn Menon', '7', 'B', 3, 'Male'),
('Grace Pillai', '7', 'B', 4, 'Female'),
('Henry Nair', '7', 'B', 5, 'Male'),
('Isabella Warrier', '7', 'C', 1, 'Female'),
('Jack Subramanian', '7', 'C', 2, 'Male'),
('Kate Krishnan', '7', 'C', 3, 'Female'),
('Liam Rao', '7', 'C', 4, 'Male'),
('Mia Kapoor', '7', 'C', 5, 'Female'),
('Noah Iyer', '6', 'A', 1, 'Male'),
('Olivia Menon', '6', 'A', 2, 'Female'),
('Parker Pillai', '6', 'A', 3, 'Male'),
('Quinn Nair', '6', 'A', 4, 'Female'),
('Ryan Warrier', '6', 'A', 5, 'Male'),
('Sophia Subramanian', '6', 'B', 1, 'Female'),
('Thomas Krishnan', '6', 'B', 2, 'Male'),
('Uma Rao', '6', 'B', 3, 'Female'),
('Victor Kapoor', '6', 'B', 4, 'Male'),
('Willow Iyer', '6', 'B', 5, 'Female'),
('Xander Menon', '6', 'C', 1, 'Male'),
('Yara Pillai', '6', 'C', 2, 'Female'),
('Zoe Nair', '6', 'C', 3, 'Female'),
('Aaron Warrier', '6', 'C', 4, 'Male'),
('Bella Subramanian', '6', 'C', 5, 'Female');

-- ============================================
-- INSERT DATA: Teachers
-- ============================================
INSERT INTO teachers (teacher_name, SUBJECT) VALUES
('Dr. Rajesh Kumar', 'Mathematics'),
('Prof. Sunita Sharma', 'Physics'),
('Dr. Amit Patel', 'Chemistry'),
('Ms. Priya Reddy', 'Biology'),
('Mr. Vikram Singh', 'English'),
('Dr. Anjali Mehta', 'History'),
('Prof. Ramesh Joshi', 'Geography'),
('Ms. Kavita Desai', 'Computer Science'),
('Dr. Manoj Agarwal', 'Economics'),
('Mrs. Sneha Iyer', 'Hindi');

-- ============================================
-- INSERT DATA: Subjects
-- ============================================
INSERT INTO subjects (subject_name) VALUES
('Mathematics'),
('Physics'),
('Chemistry'),
('Biology'),
('English'),
('History'),
('Geography'),
('Computer Science'),
('Economics'),
('Hindi');

-- ============================================
-- INSERT DATA: Exams
-- ============================================
INSERT INTO exams (exam_name, class) VALUES
('Mid Term Exam', '10'),
('Final Exam', '10'),
('Unit Test 1', '10'),
('Unit Test 2', '10'),
('Mid Term Exam', '9'),
('Final Exam', '9'),
('Unit Test 1', '9'),
('Mid Term Exam', '11'),
('Final Exam', '11'),
('Unit Test 1', '11'),
('Mid Term Exam', '12'),
('Final Exam', '12'),
('Unit Test 1', '12'),
('Mid Term Exam', '8'),
('Final Exam', '8'),
('Mid Term Exam', '7'),
('Final Exam', '7'),
('Mid Term Exam', '6'),
('Final Exam', '6');

-- ============================================
-- INSERT DATA: Marks (for first 50 students)
-- ============================================
INSERT INTO marks (student_id, exam_id, total_marks, obtained_marks) VALUES
(1, 1, 100, 85.5), (1, 2, 100, 92.0), (1, 3, 50, 45.0),
(2, 1, 100, 78.5), (2, 2, 100, 88.0), (2, 3, 50, 42.5),
(3, 1, 100, 92.0), (3, 2, 100, 95.5), (3, 3, 50, 48.0),
(4, 1, 100, 88.5), (4, 2, 100, 90.0), (4, 3, 50, 46.5),
(5, 1, 100, 75.0), (5, 2, 100, 82.5), (5, 3, 50, 40.0),
(6, 1, 100, 90.5), (6, 2, 100, 93.0), (6, 3, 50, 47.5),
(7, 1, 100, 82.0), (7, 2, 100, 85.5), (7, 3, 50, 43.0),
(8, 1, 100, 95.0), (8, 2, 100, 97.5), (8, 3, 50, 49.0),
(9, 1, 100, 88.0), (9, 2, 100, 91.0), (9, 3, 50, 46.0),
(10, 1, 100, 79.5), (10, 2, 100, 86.0), (10, 3, 50, 41.5),
(11, 1, 100, 93.5), (11, 2, 100, 96.0), (11, 3, 50, 48.5),
(12, 1, 100, 87.0), (12, 2, 100, 89.5), (12, 3, 50, 45.5),
(13, 1, 100, 81.5), (13, 2, 100, 84.0), (13, 3, 50, 42.0),
(14, 1, 100, 94.5), (14, 2, 100, 98.0), (14, 3, 50, 49.5),
(15, 1, 100, 76.0), (15, 2, 100, 80.5), (15, 3, 50, 39.5),
(16, 5, 100, 88.0), (16, 6, 100, 92.5), (16, 7, 50, 46.0),
(17, 5, 100, 85.5), (17, 6, 100, 90.0), (17, 7, 50, 44.5),
(18, 5, 100, 91.0), (18, 6, 100, 94.5), (18, 7, 50, 47.0),
(19, 5, 100, 83.5), (19, 6, 100, 87.0), (19, 7, 50, 43.5),
(20, 5, 100, 89.5), (20, 6, 100, 93.0), (20, 7, 50, 46.5),
(21, 5, 100, 77.0), (21, 6, 100, 81.5), (21, 7, 50, 40.5),
(22, 5, 100, 92.5), (22, 6, 100, 96.0), (22, 7, 50, 48.0),
(23, 5, 100, 86.0), (23, 6, 100, 89.5), (23, 7, 50, 45.0),
(24, 5, 100, 90.0), (24, 6, 100, 94.0), (24, 7, 50, 47.0),
(25, 5, 100, 84.5), (25, 6, 100, 88.0), (25, 7, 50, 44.0),
(26, 5, 100, 88.5), (26, 6, 100, 92.0), (26, 7, 50, 46.0),
(27, 5, 100, 79.0), (27, 6, 100, 83.5), (27, 7, 50, 41.5),
(28, 5, 100, 93.0), (28, 6, 100, 97.0), (28, 7, 50, 48.5),
(29, 5, 100, 87.5), (29, 6, 100, 91.0), (29, 7, 50, 45.5),
(30, 5, 100, 82.0), (30, 6, 100, 85.5), (30, 7, 50, 43.0);

-- ============================================
-- INSERT DATA: Attendance
-- ============================================
INSERT INTO attendance (student_id, total_days, present_days, absent_days) VALUES
(1, 200, 185, 15), (2, 200, 190, 10), (3, 200, 195, 5),
(4, 200, 188, 12), (5, 200, 180, 20), (6, 200, 192, 8),
(7, 200, 187, 13), (8, 200, 198, 2), (9, 200, 189, 11),
(10, 200, 183, 17), (11, 200, 194, 6), (12, 200, 191, 9),
(13, 200, 186, 14), (14, 200, 197, 3), (15, 200, 181, 19),
(16, 200, 193, 7), (17, 200, 188, 12), (18, 200, 196, 4),
(19, 200, 190, 10), (20, 200, 192, 8), (21, 200, 184, 16),
(22, 200, 195, 5), (23, 200, 189, 11), (24, 200, 191, 9),
(25, 200, 187, 13), (26, 200, 194, 6), (27, 200, 182, 18),
(28, 200, 196, 4), (29, 200, 190, 10), (30, 200, 188, 12),
(31, 200, 193, 7), (32, 200, 197, 3), (33, 200, 185, 15),
(34, 200, 191, 9), (35, 200, 189, 11), (36, 200, 195, 5),
(37, 200, 187, 13), (38, 200, 192, 8), (39, 200, 194, 6),
(40, 200, 190, 10), (41, 200, 196, 4), (42, 200, 188, 12),
(43, 200, 193, 7), (44, 200, 191, 9), (45, 200, 197, 3),
(46, 200, 189, 11), (47, 200, 195, 5), (48, 200, 192, 8),
(49, 200, 194, 6), (50, 200, 190, 10);

-- ============================================
-- INSERT DATA: Fees
-- ============================================
INSERT INTO fees (student_id, total_fee, paid_fee, due_fee) VALUES
(1, 50000, 50000, 0), (2, 50000, 45000, 5000), (3, 50000, 50000, 0),
(4, 50000, 48000, 2000), (5, 50000, 30000, 20000), (6, 50000, 50000, 0),
(7, 50000, 40000, 10000), (8, 50000, 50000, 0), (9, 50000, 47000, 3000),
(10, 50000, 35000, 15000), (11, 50000, 50000, 0), (12, 50000, 49000, 1000),
(13, 50000, 42000, 8000), (14, 50000, 50000, 0), (15, 50000, 25000, 25000),
(16, 45000, 45000, 0), (17, 45000, 40000, 5000), (18, 45000, 45000, 0),
(19, 45000, 43000, 2000), (20, 45000, 30000, 15000), (21, 45000, 45000, 0),
(22, 45000, 41000, 4000), (23, 45000, 45000, 0), (24, 45000, 44000, 1000),
(25, 45000, 32000, 13000), (26, 45000, 45000, 0), (27, 45000, 38000, 7000),
(28, 45000, 45000, 0), (29, 45000, 42000, 3000), (30, 45000, 28000, 17000),
(31, 55000, 55000, 0), (32, 55000, 50000, 5000), (33, 55000, 55000, 0),
(34, 55000, 52000, 3000), (35, 55000, 40000, 15000), (36, 55000, 55000, 0),
(37, 55000, 48000, 7000), (38, 55000, 55000, 0), (39, 55000, 53000, 2000),
(40, 55000, 38000, 17000), (41, 55000, 55000, 0), (42, 55000, 51000, 4000),
(43, 55000, 55000, 0), (44, 55000, 54000, 1000), (45, 55000, 35000, 20000),
(46, 60000, 60000, 0), (47, 60000, 55000, 5000), (48, 60000, 60000, 0),
(49, 60000, 58000, 2000), (50, 60000, 45000, 15000);

-- ============================================
-- INSERT DATA: Rankings
-- ============================================
INSERT INTO rankings (student_id, class_rank) VALUES
(1, 5), (2, 12), (3, 2), (4, 8), (5, 18),
(6, 3), (7, 15), (8, 1), (9, 9), (10, 20),
(11, 4), (12, 10), (13, 16), (14, 1), (15, 22),
(16, 6), (17, 13), (18, 2), (19, 11), (20, 7),
(21, 19), (22, 3), (23, 14), (24, 5), (25, 17),
(26, 8), (27, 21), (28, 1), (29, 12), (30, 15),
(31, 4), (32, 9), (33, 6), (34, 10), (35, 18),
(36, 2), (37, 13), (38, 5), (39, 11), (40, 19),
(41, 3), (42, 14), (43, 7), (44, 12), (45, 20),
(46, 1), (47, 8), (48, 4), (49, 15), (50, 9);

-- ============================================
-- INSERT DATA: Leave Records
-- ============================================
INSERT INTO leave_records (student_id, leave_type, leave_days) VALUES
(1, 'Sick Leave', 5), (2, 'Personal', 3), (3, 'Medical', 2),
(4, 'Family Emergency', 4), (5, 'Sick Leave', 8), (6, 'Personal', 2),
(7, 'Medical', 5), (8, 'Sick Leave', 1), (9, 'Personal', 4),
(10, 'Family Emergency', 6), (11, 'Sick Leave', 3), (12, 'Medical', 2),
(13, 'Personal', 5), (14, 'Sick Leave', 1), (15, 'Family Emergency', 9),
(16, 'Medical', 3), (17, 'Sick Leave', 4), (18, 'Personal', 2),
(19, 'Medical', 3), (20, 'Sick Leave', 5), (21, 'Family Emergency', 7),
(22, 'Personal', 2), (23, 'Sick Leave', 4), (24, 'Medical', 3),
(25, 'Personal', 5), (26, 'Sick Leave', 2), (27, 'Family Emergency', 8),
(28, 'Medical', 1), (29, 'Sick Leave', 4), (30, 'Personal', 5),
(31, 'Medical', 3), (32, 'Sick Leave', 2), (33, 'Personal', 4),
(34, 'Family Emergency', 3), (35, 'Sick Leave', 7), (36, 'Medical', 2),
(37, 'Personal', 4), (38, 'Sick Leave', 3), (39, 'Medical', 2),
(40, 'Family Emergency', 8), (41, 'Sick Leave', 2), (42, 'Personal', 3),
(43, 'Medical', 1), (44, 'Sick Leave', 4), (45, 'Family Emergency', 9),
(46, 'Personal', 2), (47, 'Sick Leave', 3), (48, 'Medical', 2),
(49, 'Personal', 4), (50, 'Family Emergency', 7);

-- ============================================
-- INSERT DATA: Class Summary
-- ============================================
INSERT INTO class_summary (class, section, total_students) VALUES
('10', 'A', 5), ('10', 'B', 5), ('10', 'C', 5),
('9', 'A', 5), ('9', 'B', 5), ('9', 'C', 5),
('11', 'A', 5), ('11', 'B', 5), ('11', 'C', 5),
('12', 'A', 5), ('12', 'B', 5), ('12', 'C', 5),
('8', 'A', 5), ('8', 'B', 5), ('8', 'C', 5),
('7', 'A', 5), ('7', 'B', 5), ('7', 'C', 5),
('6', 'A', 5), ('6', 'B', 5), ('6', 'C', 5);
