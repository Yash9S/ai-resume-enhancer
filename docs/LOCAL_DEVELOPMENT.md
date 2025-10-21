# Local Development Setup with Ollama

## 🏠 Local AI Resume Parser - Zero Cost Setup

Your application is now configured to use **Ollama** for completely free, private AI processing on your local machine.

### ✅ What's Already Configured

1. **Ollama Container**: Running on `localhost:11434`
2. **AI Model**: `llama3.2:3b` (2GB, optimized for text processing)
3. **Rails App**: Configured to prioritize Ollama for all AI tasks
4. **Zero Cost**: No API keys needed, completely free!

### 🚀 Quick Start

Your setup is complete! The application will automatically use Ollama for:

- ✅ **Resume Text Extraction** from PDF files
- ✅ **Content Enhancement** with AI suggestions  
- ✅ **Job Matching Analysis** and scoring
- ✅ **Privacy**: All processing happens locally

### 📊 Performance Expectations

| Task | Time | Quality | Cost |
|------|------|---------|------|
| Resume Extraction | 10-15s | Good | FREE |
| Content Enhancement | 8-12s | Good | FREE |
| Job Matching | 5-8s | Good | FREE |

*Note: First request may take longer as the model loads*

### 🔧 Container Management

```bash
# Check Ollama status
docker ps | grep ollama

# View Ollama logs
docker logs ollama-ai

# Restart Ollama if needed
docker restart ollama-ai

# Check available models
docker exec ollama-ai ollama list

# Pull additional models (optional)
docker exec ollama-ai ollama pull llama3.2:1b  # Smaller, faster model
```

### 🎯 Testing Your Setup

Run the test script to verify everything is working:

```bash
ruby scripts/test_ollama.rb
```

Expected output: ✅ All tests should pass

### 💡 Tips for Local Development

1. **Model Loading**: First AI request takes ~30 seconds (model loading)
2. **Memory Usage**: Ollama uses ~4GB RAM when active
3. **Performance**: Better on machines with 16GB+ RAM
4. **Offline Work**: Works completely offline once set up

### 🔄 Application Behavior

Your Rails app now follows this priority:

1. 🟢 **Ollama** (if available) - Local AI processing
2. 🟡 **Basic Processing** - Simple text parsing (fallback)
3. 🔵 **Other APIs** (if configured) - Cloud services

### 📝 Environment Variables

Current configuration in `docker-compose.yml`:

```yaml
environment:
  OLLAMA_BASE_URL: http://host.docker.internal:11434  # ✅ Enabled
  # HUGGINGFACE_API_KEY: (not needed)
  # OPENAI_API_KEY: (not needed)
```

### 🚨 Troubleshooting

**If resume processing fails:**

1. Check Ollama is running: `docker ps | grep ollama`
2. Test connection: `ruby scripts/test_ollama.rb`
3. Check logs: `docker-compose logs worker --tail=20`
4. Restart if needed: `docker restart ollama-ai`

**If processing is slow:**
- First request is always slower (model loading)
- Subsequent requests are much faster
- Consider the 1B model for faster processing: `ollama pull llama3.2:1b`

### 🎉 Success Indicators

You'll know it's working when:

- ✅ Resume uploads complete successfully
- ✅ Processing status shows "Completed" instead of "Failed"
- ✅ Content is extracted from PDFs
- ✅ AI suggestions appear in enhancement
- ✅ Logs show "Using Ollama for resume parsing"

### 🔧 Adding More Models (Optional)

```bash
# Faster, smaller model (good for testing)
docker exec ollama-ai ollama pull llama3.2:1b

# Better quality model (needs more RAM)
docker exec ollama-ai ollama pull llama3.1:8b

# Update your service to use different model
# Edit app/services/resume_parsing_service.rb
# Change: model: 'llama3.2:1b'  # in parse_with_ollama method
```

---

## 🎯 You're All Set!

Your AI Resume Parser now runs completely free with local AI. Upload a resume to test it out!

**Next Steps:**
1. Upload a test resume at `http://localhost:3000`
2. Watch the processing complete successfully
3. See AI-generated enhancements and suggestions

**Need help?** Check the logs: `docker-compose logs web worker`