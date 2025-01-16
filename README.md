
# Update master recurring events (default)
ruby calendar_notifications.rb

# Update individual instances
ruby calendar_notifications.rb --recurring-strategy individual

# Dry run with master strategy
ruby calendar_notifications.rb --dry-run

# Dry run with individual instances
ruby calendar_notifications.rb --dry-run --recurring-strategy individual
