#!/bin/bash

echo "🧪 Testing Microservices Health..."
echo

# Test AI Extraction Service
echo "📊 Testing AI Extraction Service (Port 8001):"
curl -s http://localhost:8001/health | jq . || echo "❌ AI Service not responding"
echo

# Test Frontend Service  
echo "🎨 Testing Frontend Service (Port 3000):"
curl -s http://localhost:3000/health | jq . || echo "❌ Frontend Service not responding"
echo

# Test API Gateway
echo "🔌 Testing API Gateway (Port 8080):"
curl -s http://localhost:8080/health || echo "❌ API Gateway not responding"
echo

# Test AI Providers Status
echo "🤖 Testing AI Providers:"
curl -s http://localhost:8001/ai-providers | jq . || echo "❌ Cannot get AI providers status"
echo

echo "✅ Health check complete!"
echo
echo "🔗 Service URLs:"
echo "   - AI Service: http://localhost:8001"
echo "   - Frontend: http://localhost:3000" 
echo "   - API Gateway: http://localhost:8080"
echo "   - Database: localhost:5432"
echo "   - Redis: localhost:6379"