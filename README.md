# Google Calendar Notifications Updater

This script helps manage notification settings for Google Calendar events by automatically adding specified notification times to events. It can handle both one-time and recurring events, with options to skip certain event types and handle invalid events.

## AI Generation Notice

This script and documentation were generated through a conversation with an AI assistant (Claude 3.5 Sonnet). The implementation was iteratively developed through prompts and feedback, focusing on robustness, error handling, and user experience.

## Features

- Add multiple notification times to calendar events (default: 2 and 5 minutes)
- Skip specific event types:
  - All-day events
  - Events marked as "OOO" (Out of Office)
  - Events that already have the desired notifications
- Handle recurring events in two ways:
  - Update the master recurring event (default)
  - Update individual instances
- Identify and optionally remove invalid events
- Dry run mode to preview changes
- Detailed logging and summary statistics

## Prerequisites

### System Requirements
- Ruby 2.7 or higher
- Bundler 2.4 or higher (`gem install bundler`)

### Dependencies
The script uses specific gems as defined in the Gemfile:
- `google-apis-calendar_v3`: Google Calendar API client
- `googleauth`: Google authentication handling
- `fileutils`: File operations
- `optparse`: Command line argument parsing

### Google Calendar API Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Calendar API:
   - Navigate to "APIs & Services" > "Library"
   - Search for "Google Calendar API"
   - Click "Enable"
4. Create OAuth 2.0 credentials:
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "OAuth client ID"
   - Choose "Desktop app" as the application type
   - Name your client
   - Download the credentials
5. Rename the downloaded file to `credentials.json`

## Installation

1. Clone or download this repository:
   ```bash
   git clone <repository-url>
   cd calendar-notifications-updater
   ```

2. Install Bundler if you haven't already:
   ```bash
   gem install bundler
   ```

3. Install dependencies:
   ```bash
   bundle install
   ```

4. Set up credentials:
   - Place your `credentials.json` file in the script directory
   - First run will prompt for OAuth authentication
   - Token will be saved as `token.yaml` for future use

### Troubleshooting Installation
- If you get gem installation errors:
  ```bash
  bundle update
  bundle install
  ```
- If you get Ruby version errors:
  - Install the required Ruby version using your version manager (rbenv/rvm)
  - Set it as the local version:
    ```bash
    rbenv install 2.7.8  # or newer
    rbenv local 2.7.8
    ```
    or
    ```bash
    rvm install 2.7.8
    rvm use 2.7.8
    ```

## Usage

### Basic Usage

Run the script with default settings (updates master recurring events, doesn't remove invalid events):
```bash
bundle exec ruby calendar_notifications.rb
```

### Command Line Options

Preview changes without making them:
```bash
bundle exec ruby calendar_notifications.rb --dry-run
```

Update individual recurring event instances instead of master events:
```bash
bundle exec ruby calendar_notifications.rb --recurring-strategy individual
```

Remove invalid events instead of skipping them:
```bash
bundle exec ruby calendar_notifications.rb --remove-invalid
```

Combine options:
```bash
bundle exec ruby calendar_notifications.rb --dry-run --remove-invalid --recurring-strategy individual
```

Show help:
```bash
bundle exec ruby calendar_notifications.rb --help
```

### Output Example

```
Starting Calendar Notification Updater...
[DRY RUN MODE ENABLED] No changes will be made
[DRY RUN] Fetching events...
[DRY RUN] Processing events...
[DRY RUN] Skipping Daily Standup (all-day event)
[DRY RUN] Would update notifications for event: Team Meeting on 2025-01-17T10:00:00
          Adding notifications: 2, 5 minutes
[DRY RUN] Skipping OOO - Vacation (OOO event)

[DRY RUN] Summary:
Events that would be updated: 1
Events skipped:
  - Invalid events: 0
  - Invalid events removed: 0
  - All-day events: 1
  - OOO events: 1
  - Already configured: 0
  - Recurring instances (master updated): 0

Total events processed: 3
Recurring events strategy: master

Notification update complete!
```

## Implementation Details

### Notification Times
- Default notification times are 2 and 5 minutes before events
- These can be modified by changing the `DESIRED_REMINDERS` constant in the script

### Invalid Events
An event is considered invalid if:
- The event object is nil
- The event's start time is nil

### Recurring Events Strategies
1. Master (default):
   - Updates the master recurring event
   - Changes apply to all instances
   - More efficient but less flexible
2. Individual:
   - Updates each instance separately
   - Allows different notifications per instance
   - Takes longer to process

## Security Notes

- The script requires access to your Google Calendar
- OAuth credentials are stored locally in `credentials.json`
- Access token is cached in `token.yaml`
- Both files are listed in `.gitignore` to prevent accidental commits
- Never commit or share these files
- The script only requests the minimum required permissions (calendar.events scope)

## Error Handling

The script includes comprehensive error handling for:
- API authentication issues
- Invalid event data
- API rate limits and timeouts
- File access errors

## Development

### Testing
The project uses RSpec for testing. To run the tests:

```bash
bundle exec rspec
```

To run specific test files:
```bash
bundle exec rspec spec/calendar_notifications_spec.rb
```

To run with detailed output:
```bash
bundle exec rspec --format documentation
```

### File Structure
```
.
├── README.md
├── Gemfile
├── Gemfile.lock
├── calendar_notifications.rb
├── .gitignore
├── credentials.json  (you need to add this)
├── token.yaml       (generated on first run)
└── spec/
    ├── spec_helper.rb
    └── calendar_notifications_spec.rb
```

### Version Requirements
- Ruby version: ~> 2.7
- Bundler version: ~> 2.4
- See Gemfile for specific gem version requirements

## Contributing

This script was AI-generated but welcomes improvements. When contributing:
1. Start with a dry run to validate changes
2. Test with different event types (all-day, recurring, OOO)
3. Maintain or improve the existing error handling
4. Update documentation for any new features
5. Ensure all dependencies are properly specified in the Gemfile

## License

This script is provided "as is" under the MIT License. Use at your own risk.

## Disclaimer

This is an unofficial tool and not associated with Google. Always review changes in dry-run mode first and ensure you have proper backups of your calendar data.