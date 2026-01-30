-- Create the database if it doesn't exist
CREATE DATABASE IF NOT EXISTS school_ai_system;

-- Use the database
USE school_ai_system;

-- Create search_history table (required for chatbot)
CREATE TABLE IF NOT EXISTS search_history (
  id INT AUTO_INCREMENT PRIMARY KEY,
  question TEXT NOT NULL,
  generated_sql TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

