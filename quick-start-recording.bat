@echo off
title AI Resume Parser - Quick Start for Recording

echo 🎬 Starting AI Resume Parser for Video Recording...
echo.

echo 📂 Setting up environment...
cd /d "C:\Users\Yashwanth Sonti\Desktop\Projects\ai-resume-parser"

echo.
echo 🐳 Starting microservices...
cd microservices
start "AI Microservices" cmd /k "docker-compose up && pause"

echo.
echo ⏳ Waiting for services to start...
timeout /t 15 /nobreak > nul

echo.
echo 🔍 Verifying AI service...
curl -s http://localhost:8001/health

echo.
echo 🚀 Starting Rails application...
cd ..
start "Rails Server" cmd /k "rails server"

echo.
echo ⏳ Waiting for Rails to start...
timeout /t 10 /nobreak > nul

echo.
echo 📱 Opening browser for recording...
start http://test.localhost:3000

echo.
echo ✅ All services started!
echo 🎯 Ready for video recording!
echo.
echo 📋 Recording checklist:
echo    ✓ AI microservice running on port 8001
echo    ✓ Rails application running on port 3000  
echo    ✓ Browser opened to test.localhost:3000
echo    ✓ Multi-tenant setup ready
echo.
echo 🎥 You can now start recording your demo!

pause