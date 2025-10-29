# SIDEKIQ WORKER FILES - DO NOT DELETE
# These files solve the Windows + Ruby 3.4 + Sidekiq compatibility issues

## Core Files:
- start_sidekiq.rb        # Main Sidekiq startup script 
- sidekiq_worker.bat      # Windows batch file for easy startup
- .env.development        # Environment variables (REDIS_URL, RUBY_AI_SERVICE_URL)

## Why These Files Matter:
1. Windows has issues with `bundle exec sidekiq` command
2. Ruby 3.4 has gem compatibility problems with direct Sidekiq execution
3. These scripts bypass those issues and start Sidekiq reliably

## Usage:
- Always use `sidekiq_worker.bat` to start Sidekiq
- Never delete these files
- If you move the project, update paths in sidekiq_worker.bat

## Backup Command (if files are lost):
```ruby
# In Rails console:
require 'sidekiq/cli'
cli = Sidekiq::CLI.instance
cli.parse(['--environment', 'development', '--queue', 'default,high'])
cli.run
```