require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'date'
require 'fileutils'
require 'optparse'

class CalendarNotificationUpdater
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
  APPLICATION_NAME = 'Calendar Notification Updater'.freeze
  CREDENTIALS_PATH = 'credentials.json'.freeze
  TOKEN_PATH = 'token.yaml'.freeze
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR

  def initialize(dry_run: false)
    @dry_run = dry_run
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

    puts "#{@dry_run ? '[DRY RUN] ' : ''}Fetching events..."
    response = @service.list_events(
      calendar_id,
      single_events: true,
      time_min: start_date.rfc3339,
      time_max: end_date.rfc3339,
      order_by: 'startTime'
    )

    changes_count = 0
    skipped_count = 0

    puts "#{@dry_run ? '[DRY RUN] ' : ''}Processing events..."
    response.items.each do |event|
      if event.start.date
        puts "#{@dry_run ? '[DRY RUN] ' : ''}Skipping all-day event: #{event.summary}"
        skipped_count += 1
        next
      end

      # Check current reminders
      current_reminders = event.reminders&.overrides&.map { |r| r.minutes } || []
      needed_reminders = [2, 5] - current_reminders

      if needed_reminders.empty?
        puts "#{@dry_run ? '[DRY RUN] ' : ''}Event already has required notifications: #{event.summary}"
        skipped_count += 1
        next
      end

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
        if @dry_run
          puts "[DRY RUN] Would update notifications for event: #{event.summary} on #{event.start.date_time}"
          puts "          Adding notifications: #{needed_reminders.join(', ')} minutes"
        else
          @service.update_event(calendar_id, event.id, event)
          puts "Updated notifications for event: #{event.summary} on #{event.start.date_time}"
          puts "Added notifications: #{needed_reminders.join(', ')} minutes"
        end
        changes_count += 1
      rescue => e
        puts "#{@dry_run ? '[DRY RUN] ' : ''}Error processing event #{event.summary}: #{e.message}"
      end
    end

    puts "\n#{@dry_run ? '[DRY RUN] ' : ''}Summary:"
    puts "Events that would be updated: #{changes_count}"
    puts "Events skipped (all-day or already configured): #{skipped_count}"
    puts "Total events processed: #{changes_count + skipped_count}"
    puts "\nNotification update complete!"
  end
end

# Parse command line options
if __FILE__ == $0
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: calendar_notifications.rb [options]"

    opts.on("-d", "--dry-run", "Show what would be done without making changes") do |d|
      options[:dry_run] = d
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  puts "Starting Calendar Notification Updater..."
  puts "[DRY RUN MODE ENABLED] No changes will be made" if options[:dry_run]
  updater = CalendarNotificationUpdater.new(dry_run: options[:dry_run])
  updater.update_notifications
end
