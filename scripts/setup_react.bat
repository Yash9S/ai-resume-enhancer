@echo off
echo 🚀 Setting up React Integration for AI Resume Parser...

echo 📦 Installing required gems...
docker-compose exec web bundle install

echo 🎨 Setting up asset pipeline...
docker-compose exec web bundle exec rails assets:precompile

echo 📁 Creating React component directories...
docker-compose exec web bash -c "mkdir -p app/assets/javascripts/components app/assets/javascripts/utils app/assets/stylesheets/components"

echo 🗄️ Setting up database...
docker-compose exec web bundle exec rails db:migrate

echo 🔄 Restarting application...
docker-compose restart web

echo ✅ React integration setup complete!
echo.
echo 🌐 Your application now supports:
echo   • React frontend via CDN (Rails 8 compatible)
echo   • Component-based architecture with custom CSS classes
echo   • API-first design for future microservices
echo   • Multitenancy-ready structure
echo   • CORS configuration for cross-origin requests
echo   • Rails 8 Propshaft asset pipeline compatibility
echo.
echo 🚀 Access your application at: http://localhost:3000
echo 📊 API endpoints available at: http://localhost:3000/api/v1/
echo.
echo Next steps:
echo 1. Visit http://localhost:3000 to see the React interface
echo 2. Test file uploads and AI processing
echo 3. Explore the API endpoints for future integrations

pause