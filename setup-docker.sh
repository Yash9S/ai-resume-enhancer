#!/bin/bash
# Docker Setup Script for AI Resume Parser

echo "🐳 Setting up AI Resume Parser with Docker..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker Desktop first."
    echo "Download from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

# Create .env file from example if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from .env.example..."
    cp .env.example .env
    echo "✅ Please edit .env file with your API keys and configuration"
fi

# Build and start the services
echo "🏗️  Building Docker images..."
docker-compose build

echo "🚀 Starting services..."
docker-compose up -d database redis

echo "⏳ Waiting for database to be ready..."
sleep 10

echo "🗄️  Setting up database..."
docker-compose run --rm web rails db:setup

echo "🌱 Seeding database..."
docker-compose run --rm web rails db:seed

echo "🎉 Setup complete! Starting all services..."
docker-compose up

echo ""
echo "🌐 Application will be available at: http://localhost:3000"
echo "📊 Sidekiq dashboard (admin only): http://localhost:3000/sidekiq"
echo "🗄️  PostgreSQL: localhost:5432"
echo "🔴 Redis: localhost:6379"
echo ""
echo "📝 To view logs: docker-compose logs -f"
echo "🛑 To stop: docker-compose down"
echo "🧹 To clean up: docker-compose down -v --remove-orphans"