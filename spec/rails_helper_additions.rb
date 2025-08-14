require 'spec_helper'
require 'rspec/rails'
require 'factory_bot_rails'

# Require all support files
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Configure RSpec
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Clean up test files after each test
  config.after do
    # Clean up any test files created during tests
    test_files = Dir.glob(Rails.root.join('spec', 'fixtures', '*.csv'))
    test_files.each do |file|
      File.delete(file) if File.exist?(file) && file.include?('test')
    end
  end
end

# AWS SDK configuration for tests
Aws.config.update(
  region: 'us-east-1',
  credentials: Aws::Credentials.new('test-key', 'test-secret')
)

# Silence AWS SDK logging in tests
Aws.config[:log_level] = :fatal
