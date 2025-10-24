-- Initialize MySQL for AI Resume Parser

-- Set charset and collation
SET NAMES utf8mb4;
SET character_set_client = utf8mb4;

-- Create the test database with proper charset
CREATE DATABASE IF NOT EXISTS ai_resume_parser_test 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

-- Grant privileges to the user
GRANT ALL PRIVILEGES ON ai_resume_parser_development.* TO 'ai_resume_parser'@'%';
GRANT ALL PRIVILEGES ON ai_resume_parser_test.* TO 'ai_resume_parser'@'%';

-- Set MySQL configurations for better Rails compatibility
SET GLOBAL sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';

-- Flush privileges
FLUSH PRIVILEGES;