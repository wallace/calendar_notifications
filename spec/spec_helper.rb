require 'rspec'
require 'webmock/rspec'
require 'timecop'

# Path to the main script
require_relative '../calendar_notifications'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true

  config.before(:each) do
    # Reset WebMock before each test
    WebMock.reset!
    
    # Disable all external HTTP connections except to googleapis.com
    WebMock.disable_net_connect!(allow: /googleapis\.com/)
  end

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.order = :random
  Kernel.srand config.seed
end

# Helper method to create mock calendar events
def create_mock_event(id:, summary:, start_time:, is_recurring: false)
  Google::Apis::CalendarV3::Event.new(
    id: id,
    summary: summary,
    start: Google::Apis::CalendarV3::EventDateTime.new(
      date_time: start_time,
      time_zone: 'UTC'
    ),
    recurring_event_id: is_recurring ? "master_#{id}" : nil
  )
end