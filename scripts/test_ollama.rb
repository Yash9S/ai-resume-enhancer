#!/usr/bin/env ruby

# Quick test script for Ollama integration
require 'httparty'
require 'json'

OLLAMA_BASE_URL = 'http://localhost:11434'

def test_ollama
  puts "🧪 Testing Ollama Connection..."
  
  # Test 1: Check if Ollama is running
  begin
    response = HTTParty.get("#{OLLAMA_BASE_URL}/api/tags", timeout: 5)
    if response.success?
      models = JSON.parse(response.body)['models']
      puts "✅ Ollama is running with #{models.length} model(s):"
      models.each { |model| puts "   - #{model['name']}" }
    else
      puts "❌ Ollama is not responding (#{response.code})"
      return false
    end
  rescue => e
    puts "❌ Cannot connect to Ollama: #{e.message}"
    puts "💡 Make sure to run: docker run -d --name ollama-ai -p 11434:11434 ollama/ollama"
    return false
  end
  
  # Test 2: Try a simple generation
  puts "\n🤖 Testing AI text generation..."
  
  test_prompt = "Extract key information from this resume: John Doe, Software Engineer, 5 years experience in Python and React."
  
  response = HTTParty.post(
    "#{OLLAMA_BASE_URL}/api/generate",
    headers: { 'Content-Type' => 'application/json' },
    body: {
      model: 'llama3.2:3b',
      prompt: test_prompt,
      stream: false,
      options: { temperature: 0.1, num_predict: 200 }
    }.to_json,
    timeout: 60
  )
  
  if response.success?
    result = JSON.parse(response.body)
    puts "✅ AI generation successful!"
    puts "📝 Sample output: #{result['response'][0..100]}..."
    return true
  else
    puts "❌ AI generation failed (#{response.code})"
    return false
  end
rescue => e
  puts "❌ Test failed: #{e.message}"
  false
end

# Run the test
puts "🚀 Ollama Integration Test for AI Resume Parser"
puts "=" * 50

if test_ollama
  puts "\n🎉 Ollama is ready for resume processing!"
  puts "💡 Your Rails app will now use free local AI for:"
  puts "   - Resume text extraction"
  puts "   - Content enhancement"
  puts "   - Job matching analysis"
  puts "\n📊 Performance: ~10-15 seconds per resume"
  puts "💰 Cost: $0 (completely free!)"
else
  puts "\n🔧 Setup needed. Run these commands:"
  puts "   docker run -d --name ollama-ai -p 11434:11434 ollama/ollama"
  puts "   docker exec ollama-ai ollama pull llama3.2:3b"
end