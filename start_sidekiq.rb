#!/usr/bin/env ruby

# Load Rails environment
require_relative 'config/environment'

# Configure Sidekiq
require 'sidekiq/cli'

# Set up the CLI with options
cli = Sidekiq::CLI.instance

# Configure CLI options
cli.parse([
  '--environment', 'development',
  '--queue', 'default,high',
  '--verbose'
])

# Start Sidekiq
puts "🚀 Starting Sidekiq for AI Resume Parser..."
puts "📡 Redis URL: #{ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')}"
puts "🔄 Queues: default, high"
puts "🏃 Starting worker..."

cli.run