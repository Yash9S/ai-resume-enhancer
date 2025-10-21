# Alternative: Local PostgreSQL Setup

If Docker Desktop is causing issues, you can install PostgreSQL directly on Windows:

## Install PostgreSQL Locally
1. Download from: https://www.postgresql.org/download/windows/
2. Install with these settings:
   - Port: 5432
   - Username: postgres
   - Password: password (or your choice)
   - Data Directory: Default

## Configure Database
After installation, run these commands in PostgreSQL command line:

```sql
-- Create database and user
CREATE DATABASE ai_resume_parser_development;
CREATE USER ai_resume_parser WITH PASSWORD 'password';
GRANT ALL PRIVILEGES ON DATABASE ai_resume_parser_development TO ai_resume_parser;
ALTER USER ai_resume_parser CREATEDB;

-- Create test database
CREATE DATABASE ai_resume_parser_test;
GRANT ALL PRIVILEGES ON DATABASE ai_resume_parser_test TO ai_resume_parser;
```

## Update Database.yml (if switching to local PostgreSQL)
```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  host: localhost
  port: 5432
  username: ai_resume_parser
  password: password
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: ai_resume_parser_development

test:
  <<: *default
  database: ai_resume_parser_test
```

## Start PostgreSQL Service (Windows)
```powershell
# Start PostgreSQL service
net start postgresql-x64-16

# Stop PostgreSQL service  
net stop postgresql-x64-16
```

This way PostgreSQL will start automatically with Windows and won't depend on Docker Desktop.