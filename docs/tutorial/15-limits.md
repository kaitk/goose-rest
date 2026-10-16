# 15. Limits

Every wait is bounded: a route waits up to a time limit, a service's mailbox holds a
fixed number of jobs, and a worker holds a fixed number of waiting routes. This page
shows what the client receives at each limit and what the service does when a client
stops waiting. [goose-http's limits](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#limits)
explains the event-loop side: its bounds, slow clients, and the resources held by a wait.

[`15-limits`](15-limits/main.goose) requests a project's summary from the database. The
`ms` parameter adds that many milliseconds to simulate a slow query. The route waits
at most 200 ms, and the database's mailbox holds two jobs:

```rust
// The longest a route waits for the database, in milliseconds.
let WAIT_MS: i64 = 200;
```

```rust
    // Two slots, the fewest a box has: two jobs waiting behind the one the
    // database works on fill it.
    let dbox, e = http::mail_open(2, 256);
```

## 504 for a late reply

The last argument to `rest::ask` is the time limit, which defaults to 5 seconds. When
the limit expires, the route answers 504 `timeout` and the worker drops the reply
when it arrives:

```rust
        rest::ask(cx, cx.app.db, SUMMARY, job, Waiting.Summary, WAIT_MS);
```

```text
GET /v1/projects/1/summary?ms=500 504 {"error":"timeout"}
```

A job can't be stopped from outside. The database continues the 500 ms query, but no
route is waiting for its reply.

## 503 for a full box

While the database processes one job, subsequent jobs wait in its mailbox. If the
mailbox is full, the job isn't sent: `rest::ask` immediately answers 503
`unavailable` rather than queuing work the database won't reach in time:

```text
GET /v1/projects/1/summary?ms=500 504 {"error":"timeout"}
GET /v1/projects/1/summary 000                              gave up, its job waiting
GET /v1/projects/1/summary 000                              gave up, its job waiting
GET /v1/projects/1/summary 503 {"error":"unavailable"}
```

Size a box for the jobs a service can finish within the routes' time limit: more slots
only queue work whose clients get 504 before it starts. For more work at once, start
several service threads, each with its own box, and send each job to one of them.

## A client that has gone

A client can stop waiting while its job is queued or running: its connection closes,
or its wait times out. `rest::still_wanted(a)` says whether the route is still waiting,
so the service skips a job nobody waits for. `rest::reply_value` returns false once
the route has gone:

```rust
            if tag == SUMMARY {
                let a, ok = rest::asked<SummaryJob>(bytes);
                if ok && !rest::still_wanted(a) {
                    gone.skipped++;
                } else if ok {
                    if a.job.ms > 0 { sleep_ms(a.job.ms); }
                    let ts = db::fetch_all<db::Task>(c, "SELECT * FROM tasks WHERE project = $1 ORDER BY id", [a.job.project]);
                    // False once the client has gone, as after its 504.
                    if !rest::reply_value(a, Summary { project: a.job.project, tasks: ts.len }) { gone.dropped++; }
                }
```

The jobs for the two clients that gave up were skipped, and the reply to the route
that answered 504 was dropped:

```text
GET /v1/gone 200 {"skipped":2,"dropped":1}
```

`rest::still_wanted` is a snapshot: the client can stop waiting before the reply is sent.
A long job checks it between steps as well as before starting.

## A slow client

A client that reads its response slowly can't make the worker hold an unbounded amount of response data:
goose-http stops reading from a connection whose responses queue up, and closes one
that takes nothing for `Config.write_ms`, 10 seconds by default. A route needs no special handling
for this. The other bounds, such as `request_ms` for a request head and `body_ms`
between a body's pieces, are in [goose-http's limits](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#limits).

## Work that takes minutes

A wait holds the connection, a timer, and a slot of `Config.max_waiting`, so a report
that takes minutes doesn't fit one. It runs as a job: the route answers 202 with the
job's state at once, and the client asks for it until it's done. A reports thread keeps
each report's state and advances the running report one step between messages, so that
it replies while a report runs:

```rust
// A report's state, as GET /v1/reports/:id answers it.
struct Report { status: i32 = 200, code: u8[..32] = "", id: i64 = 0, project: i64 = 0, left: i64 = STEPS, tasks: i64 = 0 }
```

```rust
// The report has started: 202, and where to ask about it.
fn resume(w: Waiting.Started, cx) {
    let r, ok = rest::read_reply<Report>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    var body: u8[>..] = [];
    format(body, r);
    http::start(cx.out, 202);
    http::field(cx.out, "Location", str("/v1/reports/", r.id));
    http::finish(cx.out, http::JSON, body);
}
```

```text
POST /v1/projects/1/reports 202 {"id":1,"project":1,"state":"running"}
GET /v1/reports/1 200 {"id":1,"project":1,"state":"running"}
GET /v1/reports/1 200 {"id":1,"project":1,"state":"done","tasks":5}
```

These reports live in the thread's memory and are lost when the server stops. Reports
that clients must find after a restart belong in the database.

---

[Index](README.md) · Previous: [14. Two services, or a reply in pieces](14-two-services.md)
· Next: [16. Testing the application](16-testing.md)
