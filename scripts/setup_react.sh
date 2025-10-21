#!/bin/bash

# React Integration Setup Script for AI Resume Parser

echo "🚀 Setting up React Integration for AI Resume Parser..."

# 1. Install required gems
echo "📦 Installing required gems..."
docker-compose exec web bundle install

# 2. Setup asset pipeline for React
echo "🎨 Setting up asset pipeline..."
docker-compose exec web rails assets:precompile

# 3. Create necessary directories
echo "📁 Creating React component directories..."
docker-compose exec web mkdir -p app/assets/javascripts/components
docker-compose exec web mkdir -p app/assets/javascripts/utils
docker-compose exec web mkdir -p app/assets/stylesheets/components

# 4. Setup database for API serializers
echo "🗄️ Setting up database..."
docker-compose exec web rails db:migrate

# 5. Restart the application
echo "🔄 Restarting application..."
docker-compose restart web

echo "✅ React integration setup complete!"
echo ""
echo "🌐 Your application now supports:"
echo "  • React frontend with component-based architecture"
echo "  • API-first design for future microservices"
echo "  • Multitenancy-ready structure"
echo "  • Custom CSS classes (no Tailwind dependency)"
echo "  • CORS configuration for cross-origin requests"
echo ""
echo "🚀 Access your application at: http://localhost:3000"
echo "📊 API endpoints available at: http://localhost:3000/api/v1/"
echo ""
echo "Next steps:"
echo "1. Visit http://localhost:3000 to see the React interface"
echo "2. Test file uploads and AI processing"
echo "3. Explore the API endpoints for future integrations"