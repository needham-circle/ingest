# frozen_string_literal: true

module NeedhamCircle
  # The sync's window into the public Google Calendar: looking up the events a
  # source has already synced, and inserting or updating them.
  class GoogleCalendar
    class Result
      attr_reader :value #: T
      attr_reader :error #: Google::Apis::Error?

      #: (T? value, Google::Apis::Error? error) -> void
      def initialize(value, error)
        @value = value
        @error = error
      end

      #: () { () -> T } -> Result[T]
      def self.wrap
        value = yield
        new(value, nil)
      rescue Google::Apis::Error => error
        new(nil, error)
      end
    end

    #: (String key) -> void
    def initialize(key)
      @service = Google::Apis::CalendarV3::CalendarService.new
      @service.authorization =
        Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: StringIO.new(Base64.decode64(key)),
          scope: ["https://www.googleapis.com/auth/calendar.events"]
        )
    end

    # The already-synced events for a source, as a source_id => event id map,
    # so the runner can decide insert vs update per event.
    #: (String calendar_id, String source) -> Result[Hash[String, String]]
    def source_ids(calendar_id, source)
      Result.wrap do
        @service
          .list_events(
            calendar_id,
            private_extended_property: ["source=#{source}"],
            single_events: true,
            show_deleted: false,
            max_results: 2500
          )
          .items
          .each_with_object({}) do |google_event, ids|
            source_id = google_event.extended_properties&.private&.[]("source_id")
            ids[source_id] = google_event.id if source_id
          end
      end
    end

    #: (String calendar_id, String source, String? existing_event_id, Sync::Event event) -> Result[void]
    def upsert_source_event(calendar_id, source, existing_event_id, event)
      Result.wrap do
        google_event =
          Google::Apis::CalendarV3::Event.new(
            summary: event.title,
            description: event.description,
            location: event.location,
            start: source_date_time(event.start_at, event.timezone),
            end: source_date_time(event.end_at, event.timezone),
            extended_properties:
              Google::Apis::CalendarV3::Event::ExtendedProperties.new(
                private: { "source" => source, "source_id" => event.source_id }
              )
          )

        # Google rejects Event::Source with a blank url. Only attach the source
        # block when we actually have one to link to.
        if event.url && !event.url.empty?
          google_event.source =
            Google::Apis::CalendarV3::Event::Source.new(
              title: source,
              url: event.url
            )
        end

        if existing_event_id
          @service.update_event(calendar_id, existing_event_id, google_event)
        else
          @service.insert_event(calendar_id, google_event)
        end
      end
    end

    private

    #: (String iso, String timezone) -> Google::Apis::CalendarV3::EventDateTime
    def source_date_time(iso, timezone)
      Google::Apis::CalendarV3::EventDateTime.new(
        date_time: iso,
        time_zone: timezone
      )
    end
  end
end
