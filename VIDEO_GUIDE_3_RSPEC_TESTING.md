# 🧪 **Video Guide 3: Enhanced RSpec Testing Suite**

## 📋 **Overview**
This guide explains the comprehensive testing suite with multi-tenant isolation, API testing, microservice mocking, and background job testing.

---

## 🎯 **Video Recording Focus Points**

### **1. Test Architecture Overview** (2-3 minutes)
- Multi-tenant test isolation strategy
- FactoryBot for data generation
- Microservice mocking patterns
- Background job testing

### **2. File Structure Overview** (3-4 minutes)
```
Key Files to Show:
├── spec/
│   ├── rails_helper.rb                      # Main test configuration
│   ├── support/                             # Test support files
│   │   ├── tenant_helpers.rb               # Multi-tenant test utilities
│   │   ├── api_helpers.rb                  # API testing helpers
│   │   └── microservice_mocks.rb           # Service mocking
│   ├── models/                             # Model tests with tenant isolation
│   ├── requests/                           # API integration tests
│   ├── services/                           # Service layer tests
│   └── jobs/                              # Background job tests
├── factories/                              # FactoryBot definitions
└── .rspec                                 # RSpec configuration
```

---

## 📁 **File #1: Main Test Configuration**

### **📄 File: `spec/rails_helper.rb`**

**Show this exact code in your video:**

```ruby
# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
require 'shoulda/matchers'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories.
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # Configure database cleaning strategy for multi-tenant testing
  config.use_transactional_fixtures = false
  
  # Multi-tenant testing configuration
  config.before(:suite) do
    # Setup database cleaner
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with(:truncation)
    
    # Create test tenants for isolation testing
    create_test_tenants
    
    # Setup test data in public schema
    setup_global_test_data
  end
  
  config.before(:each) do |example|
    DatabaseCleaner.start
    
    # Handle tenant-specific tests
    if example.metadata[:tenant]
      switch_to_test_tenant(example.metadata[:tenant])
    elsif example.metadata[:multi_tenant]
      # Multi-tenant tests use public schema by default
      Apartment::Tenant.reset
    else
      # Regular tests use public schema
      Apartment::Tenant.reset
    end
    
    # Setup authentication context if needed
    if example.metadata[:authenticated]
      setup_authentication_context
    end
  end
  
  config.after(:each) do
    DatabaseCleaner.clean
    # Always reset to public schema after each test
    Apartment::Tenant.reset
  end
  
  config.after(:suite) do
    # Cleanup test tenants
    cleanup_test_tenants
  end

  # RSpec Rails can automatically mix in different behaviours to your tests
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!

  # Include test helpers
  config.include FactoryBot::Syntax::Methods
  config.include TenantHelpers
  config.include ApiHelpers
  config.include MicroserviceMocks
  
  # Include Devise test helpers
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  
  # ActiveJob test helpers
  config.include ActiveJob::TestHelper
  
  # Custom matchers and helpers
  config.include JsonHelpers, type: :request
  config.include FileHelpers
end

# Shoulda Matchers Configuration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Configure Apartment for testing
Apartment.configure do |config|
  config.excluded_models = %w{ Tenant User }
  config.tenant_names = -> { ['test_tenant_1', 'test_tenant_2', 'test_tenant_3'] }
  config.use_schemas = true
end

# Database Cleaner configuration
require 'database_cleaner/active_record'

DatabaseCleaner.allow_remote_database_url = true
DatabaseCleaner[:active_record].db = :test
```

**🎥 Explain in Video:**
1. **Line 31-37**: Database cleaning strategy for multi-tenant tests
2. **Line 39-43**: Test tenant creation and global data setup
3. **Line 45-58**: Per-test tenant switching based on metadata
4. **Line 73-79**: Test helper inclusions for various functionalities
5. **Line 89-93**: Apartment configuration for test environment

---

## 📁 **File #2: Tenant Testing Helpers**

### **📄 File: `spec/support/tenant_helpers.rb`**

**Show this exact code in your video:**

```ruby
module TenantHelpers
  # Test tenant names for isolation testing
  TEST_TENANTS = %w[test_tenant_1 test_tenant_2 test_tenant_3].freeze
  
  # Create test tenants for the test suite
  def create_test_tenants
    TEST_TENANTS.each do |tenant_name|
      begin
        # Create tenant record in public schema
        Apartment::Tenant.reset
        Tenant.find_or_create_by(
          name: tenant_name.humanize,
          subdomain: tenant_name.gsub('test_tenant_', 'test'),
          schema_name: tenant_name,
          status: 'active'
        )
        
        # Create the PostgreSQL schema
        Apartment::Tenant.create(tenant_name)
        Rails.logger.info "Created test tenant: #{tenant_name}"
        
      rescue Apartment::SchemaExists
        Rails.logger.info "Test tenant schema already exists: #{tenant_name}"
      rescue => e
        Rails.logger.error "Failed to create test tenant #{tenant_name}: #{e.message}"
        raise
      end
    end
  end
  
  # Cleanup test tenants after test suite
  def cleanup_test_tenants
    TEST_TENANTS.each do |tenant_name|
      begin
        Apartment::Tenant.drop(tenant_name)
        Rails.logger.info "Dropped test tenant: #{tenant_name}"
      rescue Apartment::SchemaNotFound
        Rails.logger.info "Test tenant schema not found: #{tenant_name}"
      rescue => e
        Rails.logger.error "Failed to cleanup test tenant #{tenant_name}: #{e.message}"
      end
    end
  end
  
  # Switch to a specific test tenant
  def switch_to_test_tenant(tenant_name)
    raise ArgumentError, "Invalid test tenant: #{tenant_name}" unless TEST_TENANTS.include?(tenant_name.to_s)
    
    Apartment::Tenant.switch!(tenant_name)
    Rails.logger.debug "Switched to test tenant: #{tenant_name}"
  end
  
  # Create isolated test data in multiple tenants
  def with_tenant_isolation(&block)
    results = {}
    
    TEST_TENANTS.each do |tenant_name|
      Apartment::Tenant.switch!(tenant_name) do
        results[tenant_name] = block.call(tenant_name)
      end
    end
    
    Apartment::Tenant.reset
    results
  end
  
  # Test data isolation between tenants
  def verify_tenant_isolation(model_class, data_map)
    isolation_verified = true
    
    data_map.each do |tenant_name, expected_data|
      Apartment::Tenant.switch!(tenant_name) do
        actual_count = model_class.count
        expected_count = expected_data.is_a?(Array) ? expected_data.size : expected_data
        
        unless actual_count == expected_count
          Rails.logger.error "Tenant isolation failed for #{tenant_name}: expected #{expected_count}, got #{actual_count}"
          isolation_verified = false
        end
      end
    end
    
    Apartment::Tenant.reset
    isolation_verified
  end
  
  # Create tenant-specific test user
  def create_tenant_user(tenant_name, attributes = {})
    default_attributes = {
      email: "user@#{tenant_name}.example.com",
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Test',
      last_name: 'User'
    }
    
    Apartment::Tenant.switch!(tenant_name) do
      FactoryBot.create(:user, default_attributes.merge(attributes))
    end
  end
  
  # Setup authentication context for tenant tests
  def setup_authentication_context(tenant_name = 'test_tenant_1')
    @current_tenant = tenant_name
    @current_user = create_tenant_user(tenant_name)
    
    # Set up request headers for API tests
    @auth_headers = {
      'Authorization' => "Bearer #{generate_jwt_token(@current_user)}",
      'X-Tenant-ID' => tenant_name,
      'Content-Type' => 'application/json'
    }
  end
  
  # Generate JWT token for API authentication
  def generate_jwt_token(user)
    JWT.encode(
      {
        user_id: user.id,
        tenant_id: @current_tenant,
        exp: 1.hour.from_now.to_i
      },
      Rails.application.credentials.jwt_secret || 'test_secret',
      'HS256'
    )
  end
  
  # Setup global test data (in public schema)
  def setup_global_test_data
    Apartment::Tenant.reset
    
    # Create test tenant records
    TEST_TENANTS.each_with_index do |tenant_name, index|
      Tenant.find_or_create_by(
        name: "Test Tenant #{index + 1}",
        subdomain: tenant_name.gsub('test_tenant_', 'test'),
        schema_name: tenant_name,
        status: 'active'
      )
    end
    
    # Create admin users in public schema
    FactoryBot.create(:admin_user, email: 'admin@example.com')
  end
end
```

**🎥 Explain in Video:**
1. **Line 2**: Constant definition for test tenant names
2. **Line 6-27**: Test tenant creation with error handling
3. **Line 42-47**: Safe tenant switching with validation
4. **Line 50-60**: Cross-tenant test execution helper
5. **Line 63-77**: Tenant data isolation verification
6. **Line 80-88**: Tenant-specific user creation
7. **Line 91-102**: Authentication context setup for API tests

---

## 📁 **File #3: API Testing Helpers**

### **📄 File: `spec/support/api_helpers.rb`**

**Show this exact code in your video:**

```ruby
module ApiHelpers
  # Parse JSON response body
  def json_response
    @json_response ||= JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end
  
  # Common API headers
  def api_headers(additional_headers = {})
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json'
    }.merge(additional_headers)
  end
  
  # Authenticated API headers with JWT
  def authenticated_headers(user = nil, tenant_id = nil)
    user ||= @current_user
    tenant_id ||= @current_tenant
    
    api_headers({
      'Authorization' => "Bearer #{generate_jwt_token(user)}",
      'X-Tenant-ID' => tenant_id,
      'X-User-ID' => user.id.to_s
    })
  end
  
  # Multipart form headers for file uploads
  def multipart_headers(additional_headers = {})
    {
      'Accept' => 'application/json'
      # Don't set Content-Type for multipart, let Rails handle it
    }.merge(additional_headers)
  end
  
  # Perform authenticated GET request
  def auth_get(path, user: nil, tenant: nil, headers: {})
    get path, headers: authenticated_headers(user, tenant).merge(headers)
  end
  
  # Perform authenticated POST request
  def auth_post(path, params: {}, user: nil, tenant: nil, headers: {})
    post path, 
         params: params.to_json, 
         headers: authenticated_headers(user, tenant).merge(headers)
  end
  
  # Perform authenticated PUT request
  def auth_put(path, params: {}, user: nil, tenant: nil, headers: {})
    put path, 
        params: params.to_json, 
        headers: authenticated_headers(user, tenant).merge(headers)
  end
  
  # Perform authenticated DELETE request
  def auth_delete(path, user: nil, tenant: nil, headers: {})
    delete path, headers: authenticated_headers(user, tenant).merge(headers)
  end
  
  # Upload file with authentication
  def auth_upload(path, file_path, additional_params: {}, user: nil, tenant: nil)
    file = fixture_file_upload(file_path, 'application/pdf')
    
    post path,
         params: additional_params.merge(file: file),
         headers: multipart_headers(authenticated_headers(user, tenant))
  end
  
  # Common response assertions
  def expect_successful_response(expected_status = 200)
    expect(response).to have_http_status(expected_status)
    expect(response.content_type).to include('application/json')
  end
  
  def expect_error_response(expected_status = 400, expected_message = nil)
    expect(response).to have_http_status(expected_status)
    expect(json_response).to have_key('error')
    
    if expected_message
      expect(json_response['error']).to include(expected_message)
    end
  end
  
  def expect_validation_errors(*fields)
    expect(response).to have_http_status(422)
    expect(json_response).to have_key('errors')
    
    fields.each do |field|
      expect(json_response['errors']).to have_key(field.to_s)
    end
  end
  
  # Pagination assertions
  def expect_paginated_response(expected_items = nil)
    expect(json_response).to have_key('pagination')
    
    pagination = json_response['pagination']
    expect(pagination).to have_key('current_page')
    expect(pagination).to have_key('total_pages')
    expect(pagination).to have_key('total_count')
    
    if expected_items
      expect(json_response['data'].size).to eq(expected_items)
    end
  end
  
  # API versioning helpers
  def v1_api_path(resource_path)
    "/api/v1#{resource_path}"
  end
  
  def v2_api_path(resource_path)
    "/api/v2#{resource_path}"
  end
  
  # Test API rate limiting (if implemented)
  def expect_rate_limited
    expect(response).to have_http_status(429)
    expect(json_response['error']).to include('rate limit')
  end
  
  # Test CORS headers (for microservices)
  def expect_cors_headers
    expect(response.headers['Access-Control-Allow-Origin']).to be_present
    expect(response.headers['Access-Control-Allow-Methods']).to be_present
  end
end

# JSON matchers for cleaner tests
module JsonHelpers
  # Check if JSON response contains specific structure
  def json_includes?(key_path, expected_value = nil)
    keys = key_path.split('.')
    current = json_response
    
    keys.each do |key|
      return false unless current.is_a?(Hash) && current.key?(key)
      current = current[key]
    end
    
    expected_value.nil? || current == expected_value
  end
  
  # Extract nested JSON values
  def json_extract(key_path)
    keys = key_path.split('.')
    keys.reduce(json_response) { |hash, key| hash&.dig(key) }
  end
  
  # Validate JSON schema structure
  def expect_json_structure(expected_structure, actual_json = nil)
    actual_json ||= json_response
    
    expected_structure.each do |key, value|
      expect(actual_json).to have_key(key.to_s)
      
      if value.is_a?(Hash)
        expect_json_structure(value, actual_json[key.to_s])
      elsif value.is_a?(Class)
        expect(actual_json[key.to_s]).to be_a(value)
      end
    end
  end
end
```

**🎥 Explain in Video:**
1. **Line 2-7**: JSON response parsing with error handling
2. **Line 16-25**: Authenticated API headers with JWT and tenant context
3. **Line 34-51**: Convenience methods for authenticated HTTP requests
4. **Line 54-60**: File upload helper with multipart form handling
5. **Line 63-87**: Common response assertion helpers
6. **Line 89-96**: Pagination response validation
7. **Line 119-142**: JSON structure validation helpers

---

## 📁 **File #4: Microservice Mocking**

### **📄 File: `spec/support/microservice_mocks.rb`**

**Show this exact code in your video:**

```ruby
module MicroserviceMocks
  # Mock successful AI extraction service response
  def mock_ai_extraction_success(extracted_data = nil)
    extracted_data ||= {
      'resume_id' => SecureRandom.uuid,
      'extracted_text' => 'Software Engineer with 5 years of experience...',
      'parsed_data' => {
        'skills' => ['Ruby', 'Rails', 'JavaScript', 'React'],
        'experience_years' => 5,
        'education' => [
          {
            'degree' => 'Bachelor of Computer Science',
            'school' => 'University of Technology',
            'year' => '2018'
          }
        ],
        'contact_info' => {
          'email' => 'john.doe@example.com',
          'phone' => '+1234567890',
          'location' => 'San Francisco, CA'
        },
        'job_titles' => ['Software Engineer', 'Full Stack Developer'],
        'companies' => ['TechCorp', 'StartupXYZ']
      },
      'processing_time' => 2.5
    }
    
    allow(HTTParty).to receive(:post)
      .with(%r{ai-extraction-service.*\/api\/extract}, any_args)
      .and_return(
        OpenStruct.new(
          success?: true,
          code: 200,
          parsed_response: extracted_data,
          headers: { 'content-type' => 'application/json' }
        )
      )
  end
  
  # Mock AI extraction service failure
  def mock_ai_extraction_failure(error_message = 'AI processing failed')
    allow(HTTParty).to receive(:post)
      .with(%r{ai-extraction-service.*\/api\/extract}, any_args)
      .and_return(
        OpenStruct.new(
          success?: false,
          code: 500,
          parsed_response: { 'error' => error_message },
          headers: { 'content-type' => 'application/json' }
        )
      )
  end
  
  # Mock AI enhancement service response
  def mock_ai_enhancement_success(enhanced_content = nil)
    enhanced_content ||= "Enhanced Software Engineer Resume\n\nHighly skilled software engineer..."
    
    allow(HTTParty).to receive(:post)
      .with(%r{ai-extraction-service.*\/api\/enhance}, any_args)
      .and_return(
        OpenStruct.new(
          success?: true,
          code: 200,
          parsed_response: {
            'resume_id' => SecureRandom.uuid,
            'enhanced_content' => enhanced_content,
            'enhancement_type' => 'job_match',
            'processed_at' => Time.current.iso8601
          },
          headers: { 'content-type' => 'application/json' }
        )
      )
  end
  
  # Mock service timeout
  def mock_service_timeout(service_pattern = %r{ai-extraction-service})
    allow(HTTParty).to receive(:post)
      .with(service_pattern, any_args)
      .and_raise(Net::TimeoutError.new('execution expired'))
  end
  
  # Mock service connection error
  def mock_service_unavailable(service_pattern = %r{ai-extraction-service})
    allow(HTTParty).to receive(:post)
      .with(service_pattern, any_args)
      .and_raise(Errno::ECONNREFUSED.new('Connection refused'))
  end
  
  # Mock all microservice endpoints
  def mock_all_microservices
    mock_ai_extraction_success
    mock_ai_enhancement_success
    mock_business_api_success
    mock_health_checks
  end
  
  # Mock business API responses
  def mock_business_api_success
    allow(HTTParty).to receive(:get)
      .with(%r{business-api.*\/api\/v1}, any_args)
      .and_return(
        OpenStruct.new(
          success?: true,
          code: 200,
          parsed_response: { 'status' => 'success', 'data' => [] },
          headers: { 'content-type' => 'application/json' }
        )
      )
  end
  
  # Mock health check endpoints
  def mock_health_checks
    health_response = {
      'status' => 'healthy',
      'timestamp' => Time.current.iso8601,
      'version' => '1.0.0'
    }
    
    %w[ai-extraction-service business-api frontend].each do |service|
      allow(HTTParty).to receive(:get)
        .with(%r{#{service}.*\/health}, any_args)
        .and_return(
          OpenStruct.new(
            success?: true,
            code: 200,
            parsed_response: health_response.merge('service' => service),
            headers: { 'content-type' => 'application/json' }
          )
        )
    end
  end
  
  # Reset all mocks
  def reset_microservice_mocks
    allow(HTTParty).to receive(:post).and_call_original
    allow(HTTParty).to receive(:get).and_call_original
    allow(HTTParty).to receive(:put).and_call_original
    allow(HTTParty).to receive(:delete).and_call_original
  end
  
  # Verify service calls were made
  def expect_ai_service_called(endpoint_pattern = %r{\/api\/extract})
    expect(HTTParty).to have_received(:post)
      .with(endpoint_pattern, any_args)
      .at_least(:once)
  end
  
  def expect_service_not_called(service_pattern = %r{ai-extraction-service})
    expect(HTTParty).not_to have_received(:post)
      .with(service_pattern, any_args)
  end
  
  # Mock MicroserviceClient directly
  def mock_microservice_client(service_name, responses = {})
    client_double = instance_double(MicroserviceClient)
    
    allow(MicroserviceClient).to receive(:new)
      .with(service_name)
      .and_return(client_double)
    
    # Setup default responses
    allow(client_double).to receive(:post).and_return(
      OpenStruct.new(success?: true, data: responses[:post] || {})
    )
    
    allow(client_double).to receive(:get).and_return(
      OpenStruct.new(success?: true, data: responses[:get] || {})
    )
    
    allow(client_double).to receive(:upload_file).and_return(
      OpenStruct.new(success?: true, data: responses[:upload] || {})
    )
    
    client_double
  end
end
```

**🎥 Explain in Video:**
1. **Line 2-29**: Mock successful AI extraction with realistic test data
2. **Line 33-43**: Mock service failure scenarios
3. **Line 67-73**: Mock network timeout errors
4. **Line 76-81**: Mock connection refused errors
5. **Line 84-89**: Mock all services for integration tests
6. **Line 122-137**: Verify service interaction assertions
7. **Line 140-157**: Mock MicroserviceClient class directly

---

## 📁 **File #5: Model Tests with Tenant Isolation**

### **📄 File: `spec/models/resume_spec.rb`**

**Show this exact code in your video:**

```ruby
require 'rails_helper'

RSpec.describe Resume, type: :model do
  describe 'validations' do
    subject { FactoryBot.build(:resume) }
    
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:file) }
    it { should belong_to(:user) }
  end
  
  describe 'tenant isolation', :multi_tenant do
    let(:tenant_1) { 'test_tenant_1' }
    let(:tenant_2) { 'test_tenant_2' }
    
    it 'isolates resume data between tenants' do
      # Create resume in tenant 1
      resume_1 = nil
      Apartment::Tenant.switch!(tenant_1) do
        user_1 = FactoryBot.create(:user, email: 'user1@tenant1.com')
        resume_1 = FactoryBot.create(:resume, 
          title: 'Tenant 1 Resume', 
          user: user_1
        )
      end
      
      # Create resume in tenant 2
      resume_2 = nil
      Apartment::Tenant.switch!(tenant_2) do
        user_2 = FactoryBot.create(:user, email: 'user2@tenant2.com')
        resume_2 = FactoryBot.create(:resume, 
          title: 'Tenant 2 Resume', 
          user: user_2
        )
      end
      
      # Verify isolation - tenant 1 only sees its data
      Apartment::Tenant.switch!(tenant_1) do
        expect(Resume.count).to eq(1)
        expect(Resume.first.title).to eq('Tenant 1 Resume')
        expect { Resume.find(resume_2.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
      
      # Verify isolation - tenant 2 only sees its data
      Apartment::Tenant.switch!(tenant_2) do
        expect(Resume.count).to eq(1)
        expect(Resume.first.title).to eq('Tenant 2 Resume')
        expect { Resume.find(resume_1.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    
    it 'maintains data integrity across multiple tenants' do
      # Create data in multiple tenants
      data_map = with_tenant_isolation do |tenant_name|
        user = FactoryBot.create(:user, email: "user@#{tenant_name}.com")
        resumes = FactoryBot.create_list(:resume, 3, user: user)
        resumes.map(&:id)
      end
      
      # Verify each tenant has correct data count
      expect(verify_tenant_isolation(Resume, data_map)).to be_truthy
      
      # Verify specific data in each tenant
      data_map.each do |tenant_name, resume_ids|
        Apartment::Tenant.switch!(tenant_name) do
          expect(Resume.pluck(:id).sort).to eq(resume_ids.sort)
        end
      end
    end
  end
  
  describe 'AI processing', :tenant do
    let(:resume) { FactoryBot.create(:resume_with_file) }
    
    before do
      mock_ai_extraction_success
    end
    
    it 'processes PDF content with AI service' do
      result = resume.process_with_ai
      
      expect(result).to be_successful
      expect(resume.reload.extracted_content).to be_present
      expect(resume.extracted_data['skills']).to include('Ruby', 'Rails')
    end
    
    it 'handles AI service failures gracefully' do
      mock_ai_extraction_failure('Processing timeout')
      
      expect { resume.process_with_ai }.to raise_error(StandardError, /Processing timeout/)
      expect(resume.reload.extracted_content).to be_nil
    end
  end
  
  describe 'callbacks', :tenant do
    let(:user) { FactoryBot.create(:user) }
    
    it 'sets default status on creation' do
      resume = FactoryBot.create(:resume, user: user)
      expect(resume.status).to eq('pending')
    end
    
    it 'updates search vector on content change' do
      resume = FactoryBot.create(:resume, user: user)
      
      expect do
        resume.update(extracted_content: 'Ruby on Rails Developer')
      end.to change { resume.search_vector }
    end
  end
  
  describe 'scopes', :tenant do
    let(:user) { FactoryBot.create(:user) }
    
    before do
      FactoryBot.create(:resume, user: user, status: 'completed')
      FactoryBot.create(:resume, user: user, status: 'processing')
      FactoryBot.create(:resume, user: user, status: 'failed')
    end
    
    it 'filters by status' do
      expect(Resume.completed.count).to eq(1)
      expect(Resume.processing.count).to eq(1)
      expect(Resume.failed.count).to eq(1)
    end
    
    it 'orders by creation date' do
      resumes = Resume.recent
      expect(resumes.first.created_at).to be >= resumes.last.created_at
    end
  end
end
```

**🎥 Explain in Video:**
1. **Line 13-45**: Tenant isolation testing with data verification
2. **Line 47-62**: Cross-tenant data integrity verification
3. **Line 65-78**: AI service integration testing with mocks
4. **Line 80-85**: Error handling for service failures
5. **Line 88-99**: Model callbacks testing
6. **Line 101-115**: Scopes and query testing within tenant context

---

## 📁 **File #6: API Request Tests**

### **📄 File: `spec/requests/api/v1/resumes_spec.rb`**

**Show this exact code in your video:**

```ruby
require 'rails_helper'

RSpec.describe 'API V1 Resumes', type: :request do
  let(:tenant_name) { 'test_tenant_1' }
  let(:user) { create_tenant_user(tenant_name) }
  
  before do
    setup_authentication_context(tenant_name)
    mock_all_microservices
  end
  
  describe 'GET /api/v1/resumes', tenant: 'test_tenant_1' do
    before do
      FactoryBot.create_list(:resume, 5, user: user)
    end
    
    it 'returns paginated resumes for the current tenant' do
      auth_get v1_api_path('/resumes'), user: user, tenant: tenant_name
      
      expect_successful_response
      expect(json_response).to have_key('resumes')
      expect(json_response).to have_key('pagination')
      expect(json_response['resumes'].size).to eq(5)
    end
    
    it 'respects pagination parameters' do
      auth_get v1_api_path('/resumes?page=1&per_page=3'), user: user, tenant: tenant_name
      
      expect_successful_response
      expect(json_response['resumes'].size).to eq(3)
      expect(json_response['pagination']['current_page']).to eq(1)
      expect(json_response['pagination']['total_count']).to eq(5)
    end
    
    it 'does not return resumes from other tenants' do
      # Create resume in different tenant
      Apartment::Tenant.switch!('test_tenant_2') do
        other_user = FactoryBot.create(:user, email: 'other@tenant2.com')
        FactoryBot.create(:resume, user: other_user, title: 'Other Tenant Resume')
      end
      
      auth_get v1_api_path('/resumes'), user: user, tenant: tenant_name
      
      expect_successful_response
      expect(json_response['resumes'].size).to eq(5)
      expect(json_response['resumes'].none? { |r| r['title'] == 'Other Tenant Resume' }).to be_truthy
    end
  end
  
  describe 'POST /api/v1/resumes', tenant: 'test_tenant_1' do
    let(:valid_attributes) do
      {
        resume: {
          title: 'Software Engineer Resume',
          content: 'Experienced developer with 5 years...'
        }
      }
    end
    
    it 'creates a new resume' do
      expect do
        auth_post v1_api_path('/resumes'), params: valid_attributes, user: user, tenant: tenant_name
      end.to change(Resume, :count).by(1)
      
      expect_successful_response(201)
      expect(json_response['resume']['title']).to eq('Software Engineer Resume')
      expect(json_response['resume']['user_id']).to eq(user.id)
    end
    
    it 'validates required fields' do
      invalid_attributes = { resume: { title: '' } }
      
      auth_post v1_api_path('/resumes'), params: invalid_attributes, user: user, tenant: tenant_name
      
      expect_validation_errors(:title)
    end
    
    it 'processes resume with AI service when requested' do
      params = valid_attributes.merge(process_with_ai: true)
      
      auth_post v1_api_path('/resumes'), params: params, user: user, tenant: tenant_name
      
      expect_successful_response(201)
      expect_ai_service_called(%r{/api/extract})
      
      # Verify AI processing job was enqueued
      expect(ProcessResumeJob).to have_been_enqueued.with(
        Resume.last,
        hash_including(tenant_id: tenant_name, user_id: user.id)
      )
    end
  end
  
  describe 'POST /api/v1/resumes/:id/process', tenant: 'test_tenant_1' do
    let(:resume) { FactoryBot.create(:resume, user: user) }
    
    it 'starts AI processing for the resume' do
      auth_post v1_api_path("/resumes/#{resume.id}/process"), user: user, tenant: tenant_name
      
      expect_successful_response
      expect(json_response['message']).to include('processing started')
      
      # Verify status update
      expect(resume.reload.status).to eq('processing')
    end
    
    it 'includes job description in processing context' do
      job_description = FactoryBot.create(:job_description, user: user)
      params = { job_description_id: job_description.id }
      
      auth_post v1_api_path("/resumes/#{resume.id}/process"), 
                params: params, user: user, tenant: tenant_name
      
      expect_successful_response
      
      # Verify job was enqueued with job description
      expect(ProcessResumeJob).to have_been_enqueued.with(
        resume,
        job_description,
        hash_including(tenant_id: tenant_name)
      )
    end
    
    it 'handles service failures gracefully' do
      mock_service_unavailable
      
      auth_post v1_api_path("/resumes/#{resume.id}/process"), user: user, tenant: tenant_name
      
      expect_error_response(503, 'Service unavailable')
    end
  end
  
  describe 'authentication and authorization' do
    it 'requires valid JWT token' do
      get v1_api_path('/resumes')
      expect(response).to have_http_status(:unauthorized)
    end
    
    it 'requires valid tenant context' do
      headers = authenticated_headers(user, nil) # No tenant
      get v1_api_path('/resumes'), headers: headers
      
      expect(response).to have_http_status(:bad_request)
      expect(json_response['error']).to include('tenant')
    end
    
    it 'prevents cross-tenant access' do
      other_tenant_user = create_tenant_user('test_tenant_2')
      
      # Try to access tenant_1 data with tenant_2 credentials
      auth_get v1_api_path('/resumes'), user: other_tenant_user, tenant: 'test_tenant_2'
      
      expect_successful_response
      expect(json_response['resumes']).to be_empty # Should not see tenant_1 data
    end
  end
  
  describe 'error handling and resilience' do
    it 'handles microservice timeouts' do
      mock_service_timeout
      
      auth_post v1_api_path('/resumes'), 
                params: { resume: { title: 'Test' }, process_with_ai: true },
                user: user, tenant: tenant_name
      
      expect_error_response(503, 'timeout')
    end
    
    it 'provides fallback when AI service is unavailable' do
      mock_service_unavailable
      
      auth_post v1_api_path('/resumes'), 
                params: { resume: { title: 'Test Resume', content: 'Content' } },
                user: user, tenant: tenant_name
      
      # Should still create resume even if AI processing fails
      expect_successful_response(201)
      expect(Resume.last.status).to eq('pending')
    end
  end
end
```

**🎥 Explain in Video:**
1. **Line 4-10**: Test setup with tenant context and service mocking
2. **Line 12-43**: Paginated API responses with tenant isolation
3. **Line 45-73**: Resume creation with validation and AI integration
4. **Line 75-105**: AI processing endpoint with job queuing
5. **Line 107-126**: Authentication and authorization testing
6. **Line 128-146**: Error handling and service resilience testing

---

## 📁 **File #7: Background Job Tests**

### **📄 File: `spec/jobs/process_resume_job_spec.rb`**

**Show this exact code in your video:**

```ruby
require 'rails_helper'

RSpec.describe ProcessResumeJob, type: :job do
  include ActiveJob::TestHelper
  
  let(:tenant_name) { 'test_tenant_1' }
  let(:user) { create_tenant_user(tenant_name) }
  let(:resume) { nil }
  
  # Setup resume in tenant context
  around do |example|
    Apartment::Tenant.switch!(tenant_name) do
      @resume = FactoryBot.create(:resume_with_file, user: user)
      example.run
    end
  end
  
  before do
    mock_ai_extraction_success
  end
  
  describe '#perform' do
    it 'processes resume in the correct tenant context' do
      expect do
        ProcessResumeJob.perform_later(@resume.id, tenant_name, user.id)
      end.to have_enqueued_job(ProcessResumeJob)
        .with(@resume.id, tenant_name, user.id)
    end
    
    it 'maintains tenant context during job execution' do
      perform_enqueued_jobs do
        ProcessResumeJob.perform_later(@resume.id, tenant_name, user.id)
      end
      
      # Verify processing happened in correct tenant
      Apartment::Tenant.switch!(tenant_name) do
        processed_resume = Resume.find(@resume.id)
        expect(processed_resume.status).to eq('completed')
        expect(processed_resume.extracted_content).to be_present
        expect(processed_resume.extracted_data['skills']).to include('Ruby')
      end
    end
    
    it 'calls AI service with correct tenant context' do
      perform_enqueued_jobs do
        ProcessResumeJob.perform_later(@resume.id, tenant_name, user.id)
      end
      
      # Verify AI service was called with tenant headers
      expect(HTTParty).to have_received(:post).with(
        %r{ai-extraction-service.*\/api\/extract},
        hash_including(
          headers: hash_including('X-Tenant-ID' => tenant_name)
        )
      )
    end
    
    it 'handles job description matching when provided' do
      job_description = nil
      Apartment::Tenant.switch!(tenant_name) do
        job_description = FactoryBot.create(:job_description, 
          user: user,
          title: 'Senior Ruby Developer'
        )
      end
      
      perform_enqueued_jobs do
        ProcessResumeJob.perform_later(@resume.id, tenant_name, user.id, job_description.id)
      end
      
      # Verify job description was included in processing
      Apartment::Tenant.switch!(tenant_name) do
        processing = @resume.resume_processings.last
        expect(processing.job_description_id).to eq(job_description.id)
        expect(processing.match_score).to be_present
      end
    end
    
    it 'retries on transient failures' do
      # Mock service failure first, then success
      call_count = 0
      allow(HTTParty).to receive(:post) do
        call_count += 1
        if call_count == 1
          raise Net::TimeoutError.new('timeout')
        else
          OpenStruct.new(
            success?: true,
            code: 200,
            parsed_response: { 'extracted_text' => 'Resume content' }
          )
        end
      end
      
      perform_enqueued_jobs do
        ProcessResumeJob.perform_later(@resume.id, tenant_name, user.id)
      end
      
      # Should have retried and eventually succeeded
      expect(call_count).to eq(2)
      
      Apartment::Tenant.switch!(tenant_name) do
        expect(@resume.reload.status).to eq('completed')
      end
    end
    
    it 'marks resume as failed after max retries' do
      mock_service_unavailable # Permanent failure
      
      perform_enqueued_jobs do
        expect do
          ProcessResumeJob.perform_later(@resume.id, tenant_name, user.id)
        end.to raise_error(Errno::ECONNREFUSED)
      end
      
      # Should mark resume as failed
      Apartment::Tenant.switch!(tenant_name) do
        expect(@resume.reload.status).to eq('failed')
        expect(@resume.error_message).to include('Connection refused')
      end
    end
  end
  
  describe 'job priority and queue' do
    it 'uses correct queue name' do
      expect(ProcessResumeJob.queue_name).to eq('resume_processing')
    end
    
    it 'sets appropriate priority for urgent jobs' do
      job = ProcessResumeJob.perform_later(@resume.id, tenant_name, user.id, nil, { priority: 'high' })
      expect(job.priority).to be < ProcessResumeJob.new.priority
    end
  end
  
  describe 'tenant isolation in background jobs' do
    it 'processes jobs for different tenants independently' do
      # Create resume in second tenant
      tenant_2_resume = nil
      Apartment::Tenant.switch!('test_tenant_2') do
        tenant_2_user = FactoryBot.create(:user, email: 'user@tenant2.com')
        tenant_2_resume = FactoryBot.create(:resume_with_file, user: tenant_2_user)
      end
      
      # Queue jobs for both tenants
      perform_enqueued_jobs do
        ProcessResumeJob.perform_later(@resume.id, tenant_name, user.id)
        ProcessResumeJob.perform_later(tenant_2_resume.id, 'test_tenant_2', tenant_2_resume.user.id)
      end
      
      # Verify tenant 1 processing
      Apartment::Tenant.switch!(tenant_name) do
        expect(@resume.reload.status).to eq('completed')
      end
      
      # Verify tenant 2 processing
      Apartment::Tenant.switch!('test_tenant_2') do
        expect(tenant_2_resume.reload.status).to eq('completed')
      end
      
      # Verify no cross-contamination
      Apartment::Tenant.switch!(tenant_name) do
        expect { Resume.find(tenant_2_resume.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
  
  describe 'job monitoring and metrics' do
    it 'records job performance metrics' do
      start_time = Time.current
      
      perform_enqueued_jobs do
        ProcessResumeJob.perform_later(@resume.id, tenant_name, user.id)
      end
      
      # Verify job completion was logged
      Apartment::Tenant.switch!(tenant_name) do
        processing = @resume.resume_processings.last
        expect(processing.started_at).to be >= start_time
        expect(processing.completed_at).to be_present
        expect(processing.processing_time).to be > 0
      end
    end
  end
end
```

**🎥 Explain in Video:**
1. **Line 10-16**: Tenant context setup for background job testing
2. **Line 20-38**: Basic job queuing and tenant context verification
3. **Line 40-50**: AI service integration with proper headers
4. **Line 52-70**: Job description matching functionality
5. **Line 72-95**: Retry logic testing with transient failures
6. **Line 97-108**: Permanent failure handling
7. **Line 120-145**: Cross-tenant job isolation verification

---

## 🔄 **Running the Test Suite Demo**

### **Show this in your terminal during video:**

```bash
# 1. Setup test database with tenants
bundle exec rails db:test:prepare
bundle exec rspec --tag tenant_setup spec/support/tenant_helpers_spec.rb

# 2. Run model tests with tenant isolation
bundle exec rspec spec/models/resume_spec.rb --tag multi_tenant

# 3. Run API tests with authentication
bundle exec rspec spec/requests/api/v1/resumes_spec.rb --tag tenant:test_tenant_1

# 4. Run background job tests
bundle exec rspec spec/jobs/process_resume_job_spec.rb

# 5. Run full test suite with coverage
bundle exec rspec --format documentation --tag ~slow

# 6. Generate coverage report
open coverage/index.html  # View SimpleCov report
```

### **Expected Output:**

```
API V1 Resumes
  GET /api/v1/resumes
    ✓ returns paginated resumes for the current tenant
    ✓ respects pagination parameters  
    ✓ does not return resumes from other tenants
  POST /api/v1/resumes
    ✓ creates a new resume
    ✓ validates required fields
    ✓ processes resume with AI service when requested

Resume (Model)
  tenant isolation
    ✓ isolates resume data between tenants
    ✓ maintains data integrity across multiple tenants
  AI processing
    ✓ processes PDF content with AI service
    ✓ handles AI service failures gracefully

ProcessResumeJob
    ✓ processes resume in the correct tenant context
    ✓ maintains tenant context during job execution
    ✓ calls AI service with correct tenant context

Finished in 12.34 seconds (files took 2.56 seconds to load)
15 examples, 0 failures

Coverage: 94.5% -- 234/248 lines in 42 files
```

---

## 🎯 **Key Points to Emphasize in Video**

### **1. Multi-Tenant Test Strategy**
- **Schema Isolation**: Each test tenant has separate PostgreSQL schema
- **Data Integrity**: Tests verify no cross-tenant data leakage
- **Context Switching**: Proper tenant context management in tests

### **2. Comprehensive Mocking**
- **Service Isolation**: Mock external microservices for unit tests
- **Error Scenarios**: Test service failures and timeouts
- **Realistic Data**: Mock responses match actual service contracts

### **3. API Testing Patterns**
- **Authentication**: JWT-based API authentication testing
- **Tenant Context**: Proper tenant headers and validation
- **Error Handling**: Comprehensive error response testing

### **4. Background Job Testing**
- **Tenant Context**: Jobs maintain tenant context during execution
- **Retry Logic**: Test failure scenarios and retry behavior
- **Performance**: Monitor job execution metrics

### **5. Test Coverage Goals**
- **90%+ Coverage**: Comprehensive test coverage requirement
- **Critical Paths**: Focus on multi-tenant and service integration
- **Regression Prevention**: Tests prevent tenant data leakage

---

## 📝 **Video Script Outline**

1. **Introduction** (30s)
   - "Today I'll explain our comprehensive RSpec testing strategy"

2. **Test Configuration** (2m)
   - Show rails_helper.rb setup
   - Explain multi-tenant test configuration

3. **Tenant Testing Helpers** (2m)
   - Show tenant_helpers.rb
   - Demonstrate tenant isolation verification

4. **API Testing Framework** (3m)
   - Show API helpers and authentication
   - Demonstrate request testing patterns

5. **Microservice Mocking** (2m)
   - Show service mocking strategies
   - Explain error scenario testing

6. **Live Demo** (3m)
   - Run test suite with tenant isolation
   - Show coverage report and metrics

7. **Summary** (30s)
   - Key testing benefits and coverage goals

**Total Duration: ~13 minutes**