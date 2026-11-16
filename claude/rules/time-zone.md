# Time zone

I'm on Pacific Time (America/Los_Angeles). Unless I'm traveling, read and state every date and time in Pacific Time.

- A Coder workspace clock runs on UTC. From late afternoon Pacific until midnight, its date is already tomorrow. There, get the time with `TZ=America/Los_Angeles date`, not `date`. The session's "Today's date" line can be the UTC date too.
- "Today", "tonight" and "yesterday" mean my local date.
- Treat API timestamps that end in `Z` or `+00:00` as UTC. Convert them before you state them or compare them to my day.
- Write times with the zone named (PT, ET). If a time stays in UTC, label it UTC.

When I'm traveling, use the time zone where I am. My primary calendar shows trips:

- Flights appear as "Flight to <city> (UA nnnn)" or "Flight UA5237 SFO to SNA". Hotels appear as "Stay at <hotel>" with an address.
- Between the outbound flight and the return flight, I'm in the destination's time zone.
- Read the destination from the event's summary and location. The event's `timeZone` field often stays America/Los_Angeles, even for a flight out of another city.
- The calendar's own time zone and its recurring "Home" working-location events do not change when I travel.
