@echo off
echo 🚀 Starting AI Resume Extraction Service (Ollama Edition)
echo =======================================================

REM Check if Ollama is running
echo 🔍 Checking Ollama availability...
curl -s http://localhost:11434/api/tags >nul 2>&1
if %errorlevel% == 0 (
    echo ✅ Ollama is running and accessible
    echo 📋 Available models:
    curl -s http://localhost:11434/api/tags
) else (
    echo ⚠️  Ollama not detected at localhost:11434
    echo    The service will use basic fallback processing
)

echo.
echo 🏗️  Building and starting the AI service...

REM Build and start the service
docker-compose -f docker-compose-rails-integration.yml build ai-extraction-service
docker-compose -f docker-compose-rails-integration.yml up ai-extraction-service redis

echo.
echo 🎉 AI Service should be running at http://localhost:8001
echo    Health check: curl http://localhost:8001/health
echo    Providers: curl http://localhost:8001/ai-providers

pause