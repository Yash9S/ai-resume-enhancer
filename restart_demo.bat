@echo off
echo ========================================
echo AI Resume Parser - Demo Restart Script
echo ========================================
echo.

echo Stopping all containers...
docker-compose down

echo.
echo Removing old volumes to ensure clean start...
docker volume rm ai-resume-parser_mysql_data 2>nul
docker volume rm ai-resume-parser_redis_data 2>nul
docker volume rm ai-resume-parser_bundle_data 2>nul
docker volume rm ai-resume-parser_rails_cache 2>nul
docker volume rm ai-resume-parser_rails_storage 2>nul

echo.
echo Building and starting containers...
docker-compose up --build

echo.
echo ========================================
echo Demo should be available at:
echo http://localhost:3000 (main app)
echo http://acme.localhost:3000 (acme tenant)
echo http://all.localhost:3000 (admin interface)
echo ========================================
pause
