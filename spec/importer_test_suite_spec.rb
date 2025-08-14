# RSpec Test Suite for Importers and S3 Downloader
#
# This test suite provides comprehensive coverage for:
# - S3FileDownloader service
# - BaseImporter abstract class
# - Dailies importer
# - DailyHealthPillars importer
# - Integration tests
#
# To run all tests:
# bundle exec rspec
#
# To run specific test files:
# bundle exec rspec spec/services/s3_file_downloader_spec.rb
# bundle exec rspec spec/services/importer/
# bundle exec rspec spec/integration/importer_integration_spec.rb
#
# To run with coverage (if simplecov is installed):
# COVERAGE=true bundle exec rspec
#
# Test Structure:
# ├── spec/
# │   ├── fixtures/
# │   │   ├── dailies.csv
# │   │   └── daily_health_pillars.csv
# │   ├── integration/
# │   │   └── importer_integration_spec.rb
# │   ├── services/
# │   │   ├── s3_file_downloader_spec.rb
# │   │   └── importer/
# │   │       ├── base_importer_spec.rb
# │   │       ├── dailies_spec.rb
# │   │       └── daily_health_pillars_spec.rb
# │   └── support/
# │       └── shared_examples_for_importers.rb

require 'rails_helper'

RSpec.describe 'Importer Test Suite' do
  it 'has all necessary test files' do
    test_files = [
      'spec/services/s3_file_downloader_spec.rb',
      'spec/services/importer/base_importer_spec.rb',
      'spec/services/importer/dailies_spec.rb',
      'spec/services/importer/daily_health_pillars_spec.rb',
      'spec/integration/importer_integration_spec.rb'
    ]

    test_files.each do |file|
      file_path = Rails.root.join(file)
      expect(File.exist?(file_path)).to be_truthy
    end
  end

  it 'has all necessary fixture files' do
    fixture_files = [
      'spec/fixtures/dailies.csv',
      'spec/fixtures/daily_health_pillars.csv'
    ]

    fixture_files.each do |file|
      file_path = Rails.root.join(file)
      expect(File.exist?(file_path)).to be_truthy
    end
  end
end
