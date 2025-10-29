-- Initialize MySQL for AI Resume Parser

-- Set charset and collation
SET NAMES utf8mb4;
SET character_set_client = utf8mb4;

-- Create the test database with proper charset
CREATE DATABASE IF NOT EXISTS ai_resume_parser_test 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

-- Create tenant databases for multi-tenancy
CREATE DATABASE IF NOT EXISTS acme 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS techstart 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS globalsol 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS innovlabs 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

-- Create any existing tenant databases that might be missing
CREATE DATABASE IF NOT EXISTS demo 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS test 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS testorg2 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

-- Grant privileges to the user for all databases
GRANT ALL PRIVILEGES ON ai_resume_parser_development.* TO 'ai_resume_parser'@'%';
GRANT ALL PRIVILEGES ON ai_resume_parser_test.* TO 'ai_resume_parser'@'%';
GRANT ALL PRIVILEGES ON acme.* TO 'ai_resume_parser'@'%';
GRANT ALL PRIVILEGES ON techstart.* TO 'ai_resume_parser'@'%';
GRANT ALL PRIVILEGES ON globalsol.* TO 'ai_resume_parser'@'%';
GRANT ALL PRIVILEGES ON innovlabs.* TO 'ai_resume_parser'@'%';

-- Grant privileges for any existing tenant databases
GRANT ALL PRIVILEGES ON demo.* TO 'ai_resume_parser'@'%';
GRANT ALL PRIVILEGES ON test.* TO 'ai_resume_parser'@'%';
GRANT ALL PRIVILEGES ON testorg2.* TO 'ai_resume_parser'@'%';

-- Set MySQL configurations for better Rails compatibility
SET GLOBAL sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';

-- Flush privileges
FLUSH PRIVILEGES;