#!/bin/bash

# Setup script for free AI alternatives
echo "🤖 AI Resume Parser - Free Setup Guide"
echo "======================================="

echo ""
echo "Choose your AI service:"
echo "1. Hugging Face (FREE - Cloud, 30k chars/month)"
echo "2. Ollama (FREE - Local, unlimited)"
echo "3. Both (Recommended)"
echo "4. Skip (Use basic processing only)"
echo ""

read -p "Enter your choice (1-4): " choice

case $choice in
  1|3)
    echo ""
    echo "📝 Setting up Hugging Face..."
    echo "1. Visit: https://huggingface.co/join"
    echo "2. Create a free account"
    echo "3. Go to: https://huggingface.co/settings/tokens"
    echo "4. Create a new token (read access is enough)"
    echo "5. Copy the token (starts with 'hf_')"
    echo ""
    read -p "Enter your Hugging Face token: " hf_token
    
    if [[ $hf_token == hf_* ]]; then
      # Update docker-compose.yml
      sed -i "s/# HUGGINGFACE_API_KEY: hf_your_hugging_face_token/HUGGINGFACE_API_KEY: $hf_token/" docker-compose.yml
      echo "✅ Hugging Face configured!"
    else
      echo "❌ Invalid token format. Please ensure it starts with 'hf_'"
    fi
    ;;
esac

case $choice in
  2|3)
    echo ""
    echo "🖥️ Setting up Ollama (Local AI)..."
    echo ""
    
    if command -v docker &> /dev/null; then
      echo "Starting Ollama container..."
      docker run -d --name ollama-ai -v ollama:/root/.ollama -p 11434:11434 ollama/ollama
      
      echo "Downloading free AI model (this may take a few minutes)..."
      docker exec ollama-ai ollama pull llama3.2:3b
      
      # Update docker-compose.yml
      sed -i "s/# OLLAMA_BASE_URL: http:\/\/host.docker.internal:11434/OLLAMA_BASE_URL: http:\/\/host.docker.internal:11434/" docker-compose.yml
      
      echo "✅ Ollama configured!"
      echo "📊 Model size: ~2GB, RAM usage: ~4GB"
    else
      echo "❌ Docker not found. Please install Docker first."
      echo "Visit: https://docs.docker.com/get-docker/"
    fi
    ;;
esac

case $choice in
  4)
    echo "ℹ️ Using basic text processing only (no AI)"
    echo "You can always add AI services later by editing docker-compose.yml"
    ;;
esac

echo ""
echo "🚀 Setup complete! Restart your application:"
echo "docker-compose down && docker-compose up -d"
echo ""
echo "💡 Cost comparison:"
echo "   • Basic processing: $0 (built-in)"
echo "   • Hugging Face: $0 (free tier)"
echo "   • Ollama: $0 (local AI)"
echo "   • OpenAI: ~$0.005 per resume (premium quality)"
echo ""
echo "Your app will automatically use the best available service!"