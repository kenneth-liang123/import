class ExampleJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Do something later
    Rails.logger.info "ExampleJob executed with args: #{args}"
  end
end
