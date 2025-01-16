require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'date'
require 'fileutils'

class CalendarNotificationUpdater
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
  APPLICATION_NAME = 'Calendar Notification Updater'.freeze
  CREDENTIALS_PATH = 'credentials.json'.freeze
  TOKEN_PATH = 'token.yaml'.freeze
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR

  def initialize
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize
  end

  def authorize
    client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)

    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts "Open this URL in your browser and enter the resulting code:\n#{url}"
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end

  def update_notifications
    calendar_id = 'primary'
    start_date = DateTime.now
    end_date = DateTime.now >> 12  # 12 months from now

    puts "Fetching events..."
    response = @service.list_events(
      calendar_id,
      single_events: true,
      time_min: start_date.rfc3339,
      time_max: end_date.rfc3339,
      order_by: 'startTime'
    )

    puts "Processing events..."
    response.items.each do |event|
      next if event.start.date  # Skip all-day events

      # Create new reminders object with desired notification times
      new_reminders = Google::Apis::CalendarV3::Event::Reminders.new(
        use_default: false,
        overrides: [
          Google::Apis::CalendarV3::EventReminder.new(minutes: 2, method: 'popup'),
          Google::Apis::CalendarV3::EventReminder.new(minutes: 5, method: 'popup')
        ]
      )

      # Update event with new reminders
      event.reminders = new_reminders

      begin
        @service.update_event(calendar_id, event.id, event)
        puts "Updated notifications for event: #{event.summary} on #{event.start.date_time}"
      rescue => e
        puts "Error updating event #{event.summary}: #{e.message}"
      end
    end

    puts "Notification update complete!"
  end
end

# Usage
if __FILE__ == $0
  puts "Starting Calendar Notification Updater..."
  updater = CalendarNotificationUpdater.new
  updater.update_notifications
end

