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
  DESIRED_REMINDERS = [2, 5].freeze  # minutes

  def initialize(dry_run: false, recurring_strategy: :master)
    @dry_run = dry_run
    @recurring_strategy = recurring_strategy  # :master or :individual
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

  def should_skip_event?(event)
    return true if event.start.date  # Skip all-day events
    return true if event.summary&.include?('OOO')  # Skip OOO events

    # Get current reminder times
    current_reminders = event.reminders&.overrides&.map { |r| r.minutes }&.sort || []

    # Skip if all desired reminders are already set
    return true if DESIRED_REMINDERS.all? { |time| current_reminders.include?(time) }

    false
  end

  def handle_recurring_event(calendar_id, event)
    if @recurring_strategy == :master
      # Update the master event if it exists
      if event.recurring_event_id
        master_event = @service.get_event(calendar_id, event.recurring_event_id)
        return update_event_reminders(calendar_id, master_event, "(master recurring event)")
      end
    end

    # Update individual instance
    update_event_reminders(calendar_id, event, event.recurring_event_id ? "(recurring instance)" : "")
  end

  def update_event_reminders(calendar_id, event, context = "")
    return if should_skip_event?(event)

    new_reminders = Google::Apis::CalendarV3::Event::Reminders.new(
      use_default: false,
      overrides: DESIRED_REMINDERS.map do |minutes|
        Google::Apis::CalendarV3::EventReminder.new(minutes: minutes, method: 'popup')
      end
    )

    event.reminders = new_reminders

    begin
      if @dry_run
        puts "[DRY RUN] Would update notifications for event: #{event.summary} #{context} on #{event.start.date_time}"
        puts "          Adding notifications: #{DESIRED_REMINDERS.join(', ')} minutes"
      else
        @service.update_event(calendar_id, event.id, event)
        puts "Updated notifications for event: #{event.summary} #{context} on #{event.start.date_time}"
        puts "Added notifications: #{DESIRED_REMINDERS.join(', ')} minutes"
      end
      return true
    rescue => e
      puts "#{@dry_run ? '[DRY RUN] ' : ''}Error processing event #{event.summary}: #{e.message}"
      return false
    end
  end

  def update_notifications
    calendar_id = 'primary'
    start_date = DateTime.now
    end_date = DateTime.now >> 12  # 12 months from now

    puts "#{@dry_run ? '[DRY RUN] ' : ''}Fetching events..."
    response = @service.list_events(
      calendar_id,
      single_events: @recurring_strategy == :individual,  # Expand recurring events if handling individually
      time_min: start_date.rfc3339,
      time_max: end_date.rfc3339,
      order_by: 'startTime'
    )

    changes_count = 0
    skipped = {
      all_day: 0,
      ooo: 0,
      has_reminders: 0,
      recurring_instance: 0
    }

    processed_recurring_masters = Set.new

    puts "#{@dry_run ? '[DRY RUN] ' : ''}Processing events..."
    response.items.each do |event|
      if should_skip_event?(event)
        reason = if event.start.date
                  skipped[:all_day] += 1
                  "all-day event"
                elsif event.summary&.include?('OOO')
                  skipped[:ooo] += 1
                  "OOO event"
                else
                  skipped[:has_reminders] += 1
                  "already has required notifications"
                end

        puts "#{@dry_run ? '[DRY RUN] ' : ''}Skipping #{event.summary} (#{reason})"
        next
      end

      # Handle recurring events based on strategy
      if event.recurring_event_id && @recurring_strategy == :master
        # Skip if we've already processed this recurring event's master
        if processed_recurring_masters.include?(event.recurring_event_id)
          skipped[:recurring_instance] += 1
          puts "#{@dry_run ? '[DRY RUN] ' : ''}Skipping recurring instance #{event.summary} (master already updated)"
          next
        end
        processed_recurring_masters.add(event.recurring_event_id)
      end

      changes_count += 1 if handle_recurring_event(calendar_id, event)
    end

    total_skipped = skipped.values.sum

    puts "\n#{@dry_run ? '[DRY RUN] ' : ''}Summary:"
    puts "Events that would be updated: #{changes_count}"
    puts "Events skipped:"
    puts "  - All-day events: #{skipped[:all_day]}"
    puts "  - OOO events: #{skipped[:ooo]}"
    puts "  - Already configured: #{skipped[:has_reminders]}"
    puts "  - Recurring instances (master updated): #{skipped[:recurring_instance]}" if @recurring_strategy == :master
    puts "Total events processed: #{changes_count + total_skipped}"
    puts "Recurring events strategy: #{@recurring_strategy}"
    puts "\nNotification update complete!"
  end
end

# Parse command line options
if __FILE__ == $0
  options = {
    recurring_strategy: :master  # default to updating master events
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: calendar_notifications.rb [options]"

    opts.on("-d", "--dry-run", "Show what would be done without making changes") do |d|
      options[:dry_run] = d
    end

    opts.on("-r", "--recurring-strategy STRATEGY", [:master, :individual],
            "How to handle recurring events (master or individual)") do |strategy|
      options[:recurring_strategy] = strategy
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  puts "Starting Calendar Notification Updater..."
  puts "[DRY RUN MODE ENABLED] No changes will be made" if options[:dry_run]
  updater = CalendarNotificationUpdater.new(
    dry_run: options[:dry_run],
    recurring_strategy: options[:recurring_strategy]
  )
  updater.update_notifications
end
