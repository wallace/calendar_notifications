require 'spec_helper'

RSpec.describe CalendarNotificationUpdater do
  let(:dry_run) { false }
  let(:recurring_strategy) { :master }
  let(:updater) { described_class.new(dry_run: dry_run, recurring_strategy: recurring_strategy) }

  describe '#should_skip_event?' do
    context 'with invalid events' do
      it 'skips nil events' do
        expect(updater.should_skip_event?(nil)).to be true
      end

      it 'skips events with nil start time' do
        event = Google::Apis::CalendarV3::Event.new(summary: 'Test')
        expect(updater.should_skip_event?(event)).to be true
      end
    end

    context 'with all-day events' do
      it 'skips all-day events' do
        event = Google::Apis::CalendarV3::Event.new(
          summary: 'All Day Event',
          start: Google::Apis::CalendarV3::EventDateTime.new(
            date: Date.today.to_s
          )
        )
        expect(updater.should_skip_event?(event)).to be true
      end
    end

    context 'with OOO events' do
      it 'skips events with OOO in the summary' do
        event = create_mock_event(
          id: '123',
          summary: 'OOO - Vacation',
          start_time: Time.now.iso8601
        )
        expect(updater.should_skip_event?(event)).to be true
      end
    end

    context 'with events that already have required notifications' do
      it 'skips events with all required notifications' do
        event = create_mock_event(
          id: '123',
          summary: 'Meeting',
          start_time: Time.now.iso8601
        )
        event.reminders = Google::Apis::CalendarV3::Event::Reminders.new(
          use_default: false,
          overrides: [
            Google::Apis::CalendarV3::EventReminder.new(minutes: 2, method: 'popup'),
            Google::Apis::CalendarV3::EventReminder.new(minutes: 5, method: 'popup')
          ]
        )
        expect(updater.should_skip_event?(event)).to be true
      end
    end

    context 'with valid events needing updates' do
      it 'does not skip regular events without required notifications' do
        event = create_mock_event(
          id: '123',
          summary: 'Meeting',
          start_time: Time.now.iso8601
        )
        expect(updater.should_skip_event?(event)).to be false
      end
    end
  end

  describe '#handle_recurring_event' do
    let(:calendar_id) { 'primary' }

    context 'with master strategy' do
      let(:recurring_strategy) { :master }

      it 'updates the master event for recurring events' do
        event = create_mock_event(
          id: '123',
          summary: 'Recurring Meeting',
          start_time: Time.now.iso8601,
          is_recurring: true
        )
        
        master_event = create_mock_event(
          id: 'master_123',
          summary: 'Recurring Meeting',
          start_time: Time.now.iso8601
        )

        allow(updater.instance_variable_get(:@service))
          .to receive(:get_event)
          .with(calendar_id, 'master_123')
          .and_return(master_event)

        allow(updater)
          .to receive(:update_event_reminders)
          .with(calendar_id, master_event, '(master recurring event)')
          .and_return(true)

        expect(updater.handle_recurring_event(calendar_id, event)).to be true
      end
    end

    context 'with individual strategy' do
      let(:recurring_strategy) { :individual }

      it 'updates individual instances' do
        event = create_mock_event(
          id: '123',
          summary: 'Recurring Meeting Instance',
          start_time: Time.now.iso8601,
          is_recurring: true
        )

        allow(updater)
          .to receive(:update_event_reminders)
          .with(calendar_id, event, '(recurring instance)')
          .and_return(true)

        expect(updater.handle_recurring_event(calendar_id, event)).to be true
      end
    end
  end
end