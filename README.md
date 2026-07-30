# Needham Circle ingest

The daily sync that pulls events from Needham community sources into the
public Needham Circle Google Calendar. It runs on GitHub Actions
(.github/workflows/sync.yml, daily cron) with one matrix job per source, so a
broken feed never blocks the others; the matrix is enumerated from the
registered fetcher classes via `rake sync:list`.

Each source is a fetcher class in `lib/needham_circle/sync/` that knows how
to fetch and parse its feed into normalized `Sync::Event`s; the shared
`Runner` upserts them into the calendar keyed by a per-source `source_id`, so
re-running a sync updates events rather than duplicating them.

## Setup

```
bundle install
cp .env.example .env   # fill in the two values
```

`SERVICE_ACCOUNT_KEY` is a base64-encoded Google service account JSON key;
the calendar must be shared (write access) with that service account. The
GitHub Actions workflow needs the same two values as repository Actions
secrets: `SERVICE_ACCOUNT_KEY` and `EVENTS_CALENDAR_ID`.

## Usage

```
bundle exec rake sync:list          # the source names (drives the CI matrix)
bundle exec rake sync:needham_gov   # sync one source
bundle exec rake test
bin/console                         # REPL with a fetcher helper per source
```

## Adding a source

Add a fetcher class under `lib/needham_circle/sync/` that calls
`Sync.register(self)`, implements `#source` and `#fetch_events`, and add its
`require` to `lib/needham_circle.rb` plus its `Source` entry in
`lib/needham_circle/source.rb`. The rake task, CI matrix entry, and console
helper all derive from the class name automatically.
