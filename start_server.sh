#!/bin/bash

echo "Starting AI Resume Parser..."

# Install dependencies
bundle install

# Wait for database
echo "Waiting for database to be ready..."
until bundle exec rails runner 'ActiveRecord::Base.connection.execute("SELECT 1")' 2>/dev/null; do
  echo "Database not ready, waiting..."
  sleep 2
done

echo "Database is ready!"

# Run main migrations only
echo "Running main database migrations..."
bundle exec rails db:migrate

# Seed main database only
echo "Seeding main database..."
bundle exec rails db:seed

# Start the server
echo "Starting Rails server..."
bundle exec rails server -b 0.0.0.0 -p 3000
