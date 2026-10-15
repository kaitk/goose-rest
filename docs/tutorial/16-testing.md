# 16. Testing the application

Part two's application is tested in two ways, as part one's is
([Testing without sockets](09-testing.md)): in-process through TinyCC, with no
socket or thread, and against the running server over HTTP. Each approach covers
what the other can't:

| What | Without sockets | Over HTTP |
|---|---|---|
| A use case's rules, its transaction | A plain call on a job | Through its route |
| A route's checks before it asks, a route that doesn't wait | `rest::serve_one` | Yes |
| The job a route sends | `serve_one`, with a box of the test's own | Through the reply |
| 503 for a full box | `serve_one`, with that box full | Yes |
| A case function's answer to a reply, a reply in pieces, two services in turn | `serve_one`, given each reply | Yes |
| 504 for a wait that ends | `serve_one`, given the timeout | Yes, with timing |
| A reply that comes late, a client that has gone, the service's thread at work | No | Yes, with timing |

`serve_one` runs a route up to its `rest::ask`. Given the reply the service would send,
it calls the handler again with it, as `rest::serve` does, so the case function answers.
The test plays the service: no thread runs, and nothing waits. Test each case function
this way, one reply per answer it gives. Test over HTTP what needs real threads and
time: that the service replies at all, a reply after the route's wait has ended, and a
client that goes while its job waits.

How an application lays out its tests, by domain and by scenario, is in
[Testing](../best-practices/testing.md), among the best practices.

## The use cases, as plain calls

A service's use case is a function that takes a connection and a job, so a test calls
it directly, using the [`db`](db/db.goose) package with no delay per statement. From
[`13-waiting/test.goose`](13-waiting/test.goose), after the call that assigns task 3,
which [Work that waits](13-waiting.md#why-one-job-per-route) shows:

```rust
    expect(service::assign(c, service::AssignJob { project: 1, task: 4, user: 3, assignee: 2 }), 403, "not_a_member");
    expect(service::assign(c, service::AssignJob { project: 1, task: 4, user: 1, assignee: 3 }), 409, "assignee_not_a_member");
    assert(assignee(c, 4) == 0);
```

The last line checks that the refused assignment rolled back: task 4 has no assignee.
This is where a use case's rules are tested, each in microseconds, without a request.

## The routes, up to their ask

The routes and their case functions are in [`app.goose`](13-waiting/app.goose), separate
from `main`, so the test can import them as `main.goose` does. The worker's state
holds the service's address, and the test gives it a box of its own. A box needs no
thread to open, send to, or take from
([mail between threads](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#mail-between-threads)):

```rust
    // The routes, with a box of the test's own where the service's would be:
    // nothing takes from it but the test.
    let box, e = http::mail_open(2, 256);
    http::exit_on_error(e);
    var app = App { conn: c, db: http::address(box, 0) };
    fn answer(text: const u8[:], wakes: const rest::Wake[:] = []) -> u8[>..] {
        return rest::serve_one(text, app, St { .. }, wakes) { cx =>
            if rest::resumed(cx) { resume(cx.state.waiting, cx); } else { handle(cx); }
        };
    }
```

The block is the one `main.goose`'s worker gives `rest::serve`. The per-request state,
`St { .. }`, is what `rest::ask` keeps its `Waiting` variant in, and `wakes` holds the
replies the [next section](#the-case-functions-given-a-reply) gives.
A route that doesn't wait is answered whole, as is one that fails before it asks:

```rust
    expect(body_of(answer(get("/v1/in-place/projects/1"))), "{\"id\":1,\"name\":\"goose\",\"owner\":1}");
    expect(body_of(answer(put("/v1/projects/1/tasks/4/assignee?user=2", ""))),
           "{\"error\":\"invalid_parameter\",\"detail\":\"X-User: required\"}");
```

A route that asks sends its job to the box, and the handler returns without an answer.
Given no reply, `serve_one` then answers 500, as it does for any block that writes no
answer, so the test checks the job instead: it takes the job from the box, reads it with `rest::asked`, as the
service does, and passes it to the use case:

```rust
    let user1 = "X-User: 1\r\n";
    expect(answer(put("/v1/projects/1/tasks/4/assignee?user=2", user1)),
           "HTTP/1.1 500 Internal Server Error\r\nConnection: close\r\nContent-Length: 0\r\n\r\n");
    let n = http::mail_take(box) { key, tag, bytes =>
        let a, ok = rest::asked<service::AssignJob>(bytes);
        assert(ok && tag == service::ASSIGN);
        expect(service::assign(c, a.job), 200, "");
    };
    assert(n == 1 && assignee(c, 4) == 2);
```

That covers the request's path parameters, header, and query on their way into the
job. The box has two slots, so two asks fill it, and the next route gets the 503 that
[Limits](15-limits.md#503-for-a-full-box) shows, without a socket:

```rust
    answer(put("/v1/projects/1/tasks/5/assignee?user=2", user1));
    answer(put("/v1/projects/1/tasks/5/assignee?user=2", user1));
    expect(body_of(answer(put("/v1/projects/1/tasks/5/assignee?user=2", user1))), "{\"error\":\"unavailable\"}");
```

## The case functions, given a reply

A `rest::Wake` is what the service would send back: `data`, a reply's bytes, with its
`tag`, or `timeout: true` for a wait that ends without one. `rest::value_bytes` gives a
flat value's bytes, as `rest::reply_value` sends them. `serve_one` takes the wakes in
order, one for each `rest::ask` the route makes, so a route that waits on two services in
turn gets two:

```rust
    let done = rest::value_bytes(service::AssignReply { .. });
    expect(answer(put("/v1/projects/1/tasks/5/assignee?user=2", user1), [rest::Wake { data: done }]),
           "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 23\r\n\r\n{\"task\":5,\"assignee\":2}");
    let missing = rest::value_bytes(service::AssignReply { status: 404, code: "task_not_found" });
    expect(body_of(answer(put("/v1/projects/1/tasks/9/assignee?user=2", user1), [rest::Wake { data: missing }])),
           "{\"error\":\"task_not_found\"}");
    assert(http::mail_take(box) { key, tag, bytes => } == 2);
    expect(body_of(answer(put("/v1/projects/1/tasks/5/assignee?user=2", user1), [rest::Wake { timeout: true }])),
           "{\"error\":\"timeout\"}");
```

The database isn't touched: the reply says task 5 was assigned, and the test checks
what the case function makes of that, the `Waiting` variant's task and assignee in the
answer. Each route still sends its job, so the test empties the box before the box's
two slots fill.

A reply longer than a message of the worker's box, `Config.mail_size` bytes, comes in
pieces, as `rest::reply` sends it. Pass the program's `http::Config` as `serve_one`'s
last argument to split a reply as the server does: `rest::relay` sends the pieces on as
chunks, and `rest::read_reply` can't read a value from them.

`scripts/test.sh` runs every `test.goose` under `docs/tutorial/`; to run one on its own, use
`goose docs/tutorial/13-waiting/test.goose`.

## The running server

Each of part two's programs has a `requests.sh` and an `expected.txt`, which
`scripts/test-examples.sh` runs as [Testing without sockets](09-testing.md#the-whole-server)
describes: it builds the program, starts it with its service threads, and compares
each `METHOD PATH STATUS BODY` line. These test the routes with their services running:
[`13-waiting`](13-waiting/requests.sh) has each of the service's answers in the error
shape, [`14-two-services`](14-two-services/requests.sh) a reply in four pieces and a
route that waits on two services in turn, and [`15-limits`](15-limits/requests.sh) the
limits.

A request whose client gives up, such as with `curl -m`, prints status `000` with no
body, and the script goes on. `requests.sh` is a shell script, so a `sleep` line waits
between requests.

### What the timing-dependent cases rely on

These limit tests depend on timing: a wait expires, a box fills while the database is busy,
and a client disconnects before its job starts. [`15-limits`](15-limits/requests.sh)
uses fixed delays to produce each condition, with enough margin that the time curl takes
to start doesn't matter:

```sh
# The database takes 500 ms, past the route's 200: 504. It goes on with the
# job, and its answer is dropped.
req GET '/v1/projects/1/summary?ms=500'
# The database is still busy: these two jobs wait in the box's two slots,
# and their clients give up (curl prints 000). The database skips them later.
req GET /v1/projects/1/summary -m 0.05
req GET /v1/projects/1/summary -m 0.05
# The box is full: 503 at once.
req GET /v1/projects/1/summary
sleep 1
req GET /v1/gone
```

```text
GET /v1/projects/1/summary?ms=500 504 {"error":"timeout"}
GET /v1/projects/1/summary 000
GET /v1/projects/1/summary 000
GET /v1/projects/1/summary 503 {"error":"unavailable"}
GET /v1/gone 200 {"skipped":2,"dropped":1}
```

- **504.** The job takes 520 ms, its 500 ms and a 20 ms statement, and the route waits
  200, so the 504 holds however fast the machine is.
- **503.** The database works on the first job for 520 ms from its start, and the four
  requests must all reach the worker within that time. Their fixed waits total 300 ms:
  200 for the 504, and 50 for each of the two clients. That leaves about 200 ms for starting curl
  four times. This is the narrowest margin.
- **A client that has gone.** `-m 0.05` gives up at 50 ms, well before the route's
  200, so its connection closes while its job waits in the box. A client that waited
  for the 504 instead would delay the next requests until after the 520 ms.
- **The counts.** `sleep 1` lets the database finish the first job, about 100 ms after
  the 503, and skip the two that wait, before `/v1/gone` reads its counts.

The reports at the end work the same way: a report runs for 500 ms, so a request right
after the `POST` finds it running, and one after `sleep 1` finds it done. On a machine
slow enough to break these margins, raise `ms=500` and the sleeps together, and keep
the route's wait, `WAIT_MS`, below the job's whole time: its `ms` and the 20 ms statement.

---

[Index](README.md) · Previous: [15. Limits](15-limits.md) · Next:
[17. Embedded Linux](17-embedded-linux.md)
