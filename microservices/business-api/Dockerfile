FROM ruby:3.1

WORKDIR /app

# For now, create a simple Rails API placeholder
RUN gem install rails

# Create a minimal Rails API
RUN rails new . --api --skip-git --skip-test --skip-bundle

# Add basic gems for API
RUN echo 'gem "rack-cors"' >> Gemfile
RUN echo 'gem "jwt"' >> Gemfile

RUN bundle install

# Create a basic health controller
RUN mkdir -p app/controllers
COPY health_controller.rb app/controllers/

# Basic routes
RUN echo "Rails.application.routes.draw do\n  get '/health', to: 'health#index'\nend" > config/routes.rb

EXPOSE 3001

CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3001"]