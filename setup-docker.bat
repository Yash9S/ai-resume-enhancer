@echo off
REM Docker Setup Script for AI Resume Parser (Windows)

echo 🐳 Setting up AI Resume Parser with Docker...

REM Check if Docker is installed
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker is not installed. Please install Docker Desktop first.
    echo Download from: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)

REM Create .env file from example if it doesn't exist
if not exist .env (
    echo 📝 Creating .env file from .env.example...
    copy .env.example .env
    echo ✅ Please edit .env file with your API keys and configuration
)

REM Build and start the services
echo 🏗️  Building Docker images...
docker-compose build

echo 🚀 Starting services...
docker-compose up -d database redis

echo ⏳ Waiting for database to be ready...
timeout /t 15 /nobreak >nul

echo 🗄️  Setting up database...
docker-compose run --rm web rails db:setup

echo 🌱 Seeding database...
docker-compose run --rm web rails db:seed

echo 🎉 Setup complete! Starting all services...
docker-compose up

echo.
echo 🌐 Application will be available at: http://localhost:3000
echo 📊 Sidekiq dashboard (admin only): http://localhost:3000/sidekiq
echo 🗄️  PostgreSQL: localhost:5432
echo 🔴 Redis: localhost:6379
echo.
echo 📝 To view logs: docker-compose logs -f
echo 🛑 To stop: docker-compose down
echo 🧹 To clean up: docker-compose down -v --remove-orphans

pause