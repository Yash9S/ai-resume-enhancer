FROM ruby:3.1.2-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY Gemfile ./
RUN bundle install
RUN bundle lock --add-platform x86_64-linux

# Copy application code
COPY . .

# Expose port
EXPOSE 4001

# Start the server
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]