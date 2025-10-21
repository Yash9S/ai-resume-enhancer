-- Initialize PostgreSQL for AI Resume Parser

-- Create the test database
CREATE DATABASE ai_resume_parser_test;

-- Grant privileges to the user
GRANT ALL PRIVILEGES ON DATABASE ai_resume_parser_development TO ai_resume_parser;
GRANT ALL PRIVILEGES ON DATABASE ai_resume_parser_test TO ai_resume_parser;

-- Enable necessary extensions
\c ai_resume_parser_development;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

\c ai_resume_parser_test;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";