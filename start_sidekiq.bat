@echo off
echo Starting Sidekiq for AI Resume Parser...
echo Using Redis on: %REDIS_URL%

cd /d "C:\Users\Yashwanth Sonti\Desktop\Projects\ai-resume-parser"

REM Set environment variables
set RAILS_ENV=development
set REDIS_URL=redis://localhost:6379/0

REM Start Sidekiq with explicit configuration
bundle exec ruby -e "require './config/environment'; Sidekiq::CLI.instance.run(['-e', 'development', '-q', 'default', '-q', 'high'])"

pause