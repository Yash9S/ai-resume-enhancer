# React Integration Setup Script for AI Resume Parser (PowerShell)

Write-Host "🚀 Setting up React Integration for AI Resume Parser..." -ForegroundColor Green

# 1. Install required gems
Write-Host "📦 Installing required gems..." -ForegroundColor Yellow
docker-compose exec web bundle install

# 2. Setup asset pipeline for React
Write-Host "🎨 Setting up asset pipeline..." -ForegroundColor Yellow
docker-compose exec web bundle exec rails assets:precompile

# 3. Create necessary directories (if not exist)
Write-Host "📁 Creating React component directories..." -ForegroundColor Yellow
docker-compose exec web bash -c "mkdir -p app/assets/javascripts/components"
docker-compose exec web bash -c "mkdir -p app/assets/javascripts/utils"
docker-compose exec web bash -c "mkdir -p app/assets/stylesheets/components"

# 4. Setup database for API serializers
Write-Host "🗄️ Setting up database..." -ForegroundColor Yellow
docker-compose exec web bundle exec rails db:migrate

# 5. Restart the application
Write-Host "🔄 Restarting application..." -ForegroundColor Yellow
docker-compose restart web

Write-Host "✅ React integration setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Your application now supports:" -ForegroundColor Cyan
Write-Host "  • React frontend via CDN (Rails 8 compatible)"
Write-Host "  • Component-based architecture with custom CSS classes"
Write-Host "  • API-first design for future microservices"
Write-Host "  • Multitenancy-ready structure"
Write-Host "  • CORS configuration for cross-origin requests"
Write-Host "  • Rails 8 Propshaft asset pipeline compatibility"
Write-Host ""
Write-Host "🚀 Access your application at: http://localhost:3000" -ForegroundColor Magenta
Write-Host "📊 API endpoints available at: http://localhost:3000/api/v1/" -ForegroundColor Magenta
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Visit http://localhost:3000 to see the React interface"
Write-Host "2. Test file uploads and AI processing"
Write-Host "3. Explore the API endpoints for future integrations"