module Importer
  class BaseImporter
    require "csv"

    attr_reader :filepath, :errors, :test_mode_enabled

    def initialize(filepath, test_mode_enabled: false)
      @filepath = filepath
      @test_mode_enabled = test_mode_enabled
      @errors = []
    end

    def import
      raise NotImplementedError, "Subclasses must implement the import method"
    end

    private

    def missing_csv_headers(required_headers)
      actual_headers = csv_headers
      required_headers - actual_headers
    end

    def csv_headers
      return [] unless File.exist?(filepath)
      begin
        CSV.open(filepath, headers: true, &:first)&.headers || []
      rescue CSV::MalformedCSVError
        []
      end
    end
  end
end
