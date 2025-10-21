# Setup script for free AI alternatives (Windows PowerShell)

Write-Host "🤖 AI Resume Parser - Free Setup Guide" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Choose your AI service:" -ForegroundColor Yellow
Write-Host "1. Hugging Face (FREE - Cloud, 30k chars/month)" -ForegroundColor Green
Write-Host "2. Ollama (FREE - Local, unlimited)" -ForegroundColor Green  
Write-Host "3. Both (Recommended)" -ForegroundColor Green
Write-Host "4. Skip (Use basic processing only)" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Enter your choice (1-4)"

switch ($choice) {
    {$_ -in 1,3} {
        Write-Host ""
        Write-Host "📝 Setting up Hugging Face..." -ForegroundColor Yellow
        Write-Host "1. Visit: https://huggingface.co/join" -ForegroundColor White
        Write-Host "2. Create a free account" -ForegroundColor White
        Write-Host "3. Go to: https://huggingface.co/settings/tokens" -ForegroundColor White
        Write-Host "4. Create a new token (read access is enough)" -ForegroundColor White
        Write-Host "5. Copy the token (starts with 'hf_')" -ForegroundColor White
        Write-Host ""
        
        $hf_token = Read-Host "Enter your Hugging Face token"
        
        if ($hf_token -like "hf_*") {
            # Update docker-compose.yml
            $content = Get-Content "docker-compose.yml" -Raw
            $content = $content -replace "# HUGGINGFACE_API_KEY: hf_your_hugging_face_token", "HUGGINGFACE_API_KEY: $hf_token"
            Set-Content "docker-compose.yml" -Value $content
            Write-Host "✅ Hugging Face configured!" -ForegroundColor Green
        } else {
            Write-Host "❌ Invalid token format. Please ensure it starts with 'hf_'" -ForegroundColor Red
        }
    }
}

switch ($choice) {
    {$_ -in 2,3} {
        Write-Host ""
        Write-Host "🖥️ Setting up Ollama (Local AI)..." -ForegroundColor Yellow
        Write-Host ""
        
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            Write-Host "Starting Ollama container..." -ForegroundColor White
            docker run -d --name ollama-ai -v ollama:/root/.ollama -p 11434:11434 ollama/ollama
            
            Write-Host "Downloading free AI model (this may take a few minutes)..." -ForegroundColor White
            docker exec ollama-ai ollama pull llama3.2:3b
            
            # Update docker-compose.yml
            $content = Get-Content "docker-compose.yml" -Raw
            $content = $content -replace "# OLLAMA_BASE_URL: http://host.docker.internal:11434", "OLLAMA_BASE_URL: http://host.docker.internal:11434"
            Set-Content "docker-compose.yml" -Value $content
            
            Write-Host "✅ Ollama configured!" -ForegroundColor Green
            Write-Host "📊 Model size: ~2GB, RAM usage: ~4GB" -ForegroundColor Cyan
        } else {
            Write-Host "❌ Docker not found. Please install Docker first." -ForegroundColor Red
            Write-Host "Visit: https://docs.docker.com/get-docker/" -ForegroundColor White
        }
    }
}

switch ($choice) {
    4 {
        Write-Host "ℹ️ Using basic text processing only (no AI)" -ForegroundColor Blue
        Write-Host "You can always add AI services later by editing docker-compose.yml" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "🚀 Setup complete! Restart your application:" -ForegroundColor Green
Write-Host "docker-compose down; docker-compose up -d" -ForegroundColor White
Write-Host ""
Write-Host "💡 Cost comparison:" -ForegroundColor Cyan
Write-Host "   • Basic processing: $0 (built-in)" -ForegroundColor Green
Write-Host "   • Hugging Face: $0 (free tier)" -ForegroundColor Green
Write-Host "   • Ollama: $0 (local AI)" -ForegroundColor Green
Write-Host "   • OpenAI: ~$0.005 per resume (premium quality)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Your app will automatically use the best available service!" -ForegroundColor Cyan