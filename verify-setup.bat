@echo off
echo 🚀 AI Resume Parser - Pre-Recording Setup Verification

echo.
echo 📊 Checking Docker Containers...
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo.
echo 🔍 Testing AI Service Health...
curl -s http://localhost:8001/health | findstr "healthy"

echo.
echo 🤖 Checking AI Providers...
curl -s http://localhost:8001/ai-providers | findstr "ollama"

echo.
echo 🗄️ Testing Database Connection...
docker exec ai_resume_parser-database-1 pg_isready -U postgres

echo.
echo 📈 Checking Redis...
docker exec ai_resume_parser-redis-1 redis-cli ping

echo.
echo 🌐 Testing Subdomain Setup...
nslookup test.localhost

echo.
echo ✅ Setup verification complete!
echo 📹 Ready for video recording!
echo.
echo 🎯 Next steps:
echo    1. Start Rails server: rails server
echo    2. Open browser to: http://test.localhost:3000
echo    3. Login and start recording!

pause