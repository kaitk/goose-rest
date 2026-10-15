# 032: Timers for a route that began a response

Status: todo (found 2026-10-15)

A route that begins a response with `rest::begin` is called again at `MORE`, when the
client has taken what was sent, and at `CLOSED`. It has no call at a time of its own
choosing, so it can't send events over time, such as Server-Sent Events or a
progress stream, without a service that replies on a schedule. goose-http's `TIMEOUT`
gives a waiting exchange such a call, which `rest::ask` uses for its wait: goose-rest
would let a route ask for one after it has begun a response. Whether goose-http can arm
a timer on an exchange whose response is open is the first thing to check; if it can't,
that's a goose-http task.

## Acceptance criteria

- [ ] A route that began a response can ask for a call after a given time, and gets
      `http::TIMEOUT` then, in its case function, with the response still open
- [ ] It can ask again from that call, and a client that goes cancels the timer and
      gives `CLOSED`
- [ ] Tests cover events sent over time, and a client that goes between them
- [ ] An example or a tutorial section sends Server-Sent Events this way
