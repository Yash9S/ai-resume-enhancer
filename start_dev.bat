@echo off
echo 🚀 Starting AI Resume Parser Development Environment...
echo.

echo 📋 Step 1: Checking Docker Desktop...
docker --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker Desktop is not running!
    echo 💡 Please start Docker Desktop first, then run this script again.
    pause
    exit /b 1
)
echo ✅ Docker Desktop is running

echo.
echo 📋 Step 2: Starting PostgreSQL Database...
cd /d "c:\Users\Yashwanth Sonti\Desktop\Projects\ai-resume-parser"
docker-compose up database -d
if errorlevel 1 (
    echo ❌ Failed to start PostgreSQL
    pause
    exit /b 1
)
echo ✅ PostgreSQL started successfully

echo.
echo 📋 Step 3: Waiting for database to be ready...
timeout /t 5 >nul
echo ✅ Database should be ready

echo.
echo 📋 Step 4: Starting Rails Server...
echo 🌐 Application will be available at:
echo    📊 Admin Dashboard: http://all.localhost:3000/admin
echo    🏢 Tenant Example:  http://acme.localhost:3000/
echo.
echo 💡 Press Ctrl+C to stop the server
rails server

pause