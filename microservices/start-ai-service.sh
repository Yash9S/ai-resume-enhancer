#!/bin/bash

echo "🚀 Starting AI Resume Extraction Service (Ollama Edition)"
echo "======================================================="

# Check if Ollama is running
echo "🔍 Checking Ollama availability..."
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "✅ Ollama is running and accessible"
    echo "📋 Available models:"
    curl -s http://localhost:11434/api/tags | jq -r '.models[].name' | head -5
else
    echo "⚠️  Ollama not detected at localhost:11434"
    echo "   The service will use basic fallback processing"
fi

echo ""
echo "🏗️  Building and starting the AI service..."

# Build and start the service
docker-compose -f docker-compose-rails-integration.yml build ai-extraction-service
docker-compose -f docker-compose-rails-integration.yml up ai-extraction-service redis

echo ""
echo "🎉 AI Service should be running at http://localhost:8001"
echo "   Health check: curl http://localhost:8001/health"
echo "   Providers: curl http://localhost:8001/ai-providers"