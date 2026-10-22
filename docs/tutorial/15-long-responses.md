# 15. Long responses and files

A project's tasks can be exported as CSV, and its files downloaded. Either can be larger
than a worker should build whole: the worker holds a response it builds until the client
has taken all of it, and a slow client takes a long time. So these go in pieces, each
made or read when the client has taken the one before. [goose-http's long responses](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#long-responses)
covers how goose-http sends a response this way.

## A response sent in pieces

`rest::begin(cx, status, content_type, length, u)` starts the response, with a length of
-1 when it isn't known yet, which sends it chunked. Like `rest::body_in_pieces`
([page 14](14-bodies-in-pieces.md)), it keeps a variant of `Use`, `u`, in the state,
and later calls go to its case function.
The route can send the first piece at once with `rest::send`. From
[`15-long-responses`](15-long-responses/main.goose):

```rust
// GET /v1/projects/:id/tasks.csv: the header now, and the rows as the
// client takes them.
fn export_tasks(cx, project: i64) {
    rest::begin(cx, 200, "text/csv; charset=utf-8", -1, Use.Export { project: project });
    rest::send(cx, "id,title,assignee\n");
}
```

The handler is then called again, through `rest::resumed` and the case function, with
`cx.kind` `http::MORE` each time the client has taken what was sent. Each call sends the
next 500 rows, about 16 KB, and the last ends the response with `rest::end`:

```rust
fn resume(u: Use.Export, cx) {
    guard cx.kind == http::MORE else { return; }   // CLOSED: the state holds nothing to release
    var piece: u8[>..] = [];
    cx.state.next = tasks_csv(piece, cx.app.tasks, u.project, cx.state.next, ROWS_PER_PIECE);
    rest::send(cx, piece);
    if cx.state.next < 0 { rest::end(cx); }
}
```

`tasks_csv` appends up to 500 rows to `piece`, starting at the task `cx.state.next`, and
returns where the next piece starts, or -1 after the last row. So the call that sends the
last rows also ends the response. The export's progress goes in the request's
state, beside what the other routes on this page keep:

```rust
struct St {
    use: Use = Use.None,
    next: i64 = 0,                                // the export's next task
    file: http::FileBody = http::FileBody { .. }, // what's left of a download
    events: i64 = 0,                              // progress events sent
    left: i64 = 0,                                // and still to send, or -1 for no end
}
```

The worker holds one piece at a time, however many tasks a project has. A client that
reads slowly gets no `MORE` until it has read, so it can't make the worker hold more:

```text
GET /v1/projects/1/tasks.csv 200 transfer-encoding: chunked lines=2001     500 rows at each MORE
GET /v1/projects/2/tasks.csv 200 id,title,assignee ...
GET /v1/projects/9/tasks.csv 404 {"error":"project_not_found"}
GET /v1/projects/1/tasks.csv 200 transfer-encoding: chunked lines=2001     read at 20 KB a second
```

A case function that neither sends nor ends at `MORE` makes goose-http close the
connection. The case function gets `http::CLOSED` once if the response ends otherwise:
when the client goes, or when the route fails with the response begun. Its head has
already been sent, so the failure can't be answered in the error shape. The route
leaves the response open and the connection closes, so the client sees it cut short. The
export holds nothing to release, so it ignores `CLOSED`. A `HEAD` request gets the head
alone, and no calls.

## Files

`rest::file(cx, path, body, u)` answers with a file, with the statuses and fields of
goose-http's
[`http::serve_file`](https://github.com/kaitk/goose-http/blob/main/docs/api.md#files):
200, 206 for a range, 304 when the client's copy is current, or 416. It fails with 404
`file_not_found` when there is no file, and 403 `forbidden` when the program can't read
it. `http::file_path` joins the project's folder and the name from the path, decoded,
and refuses a name that would leave the folder:

```rust
// GET /v1/projects/:id/files/*name: 200, 206 for a range, 304 for a
// matching If-None-Match, 416, and 404 file_not_found.
fn download(cx, project: i64) {
    var path: u8[>..] = [];
    guard http::file_path(str(cx.app.files, "/", project), rest::param(cx, "name"), path) else {
        rest::fail(cx, 400, "bad_path");
    }
    rest::file(cx, path, cx.state.file, Use.Download);
}
```

An `http::FileBody` in the state, `body`, holds the open file and what's left to
send, so a program that serves no files keeps no file state. The case function hands each call
to `rest::send_file`, which sends the next piece of up to 64 KB at each `MORE`, ends
the response after the last, and closes the file at `CLOSED`:

```rust
fn resume(u: Use.Download, cx) { rest::send_file(cx, cx.state.file); }
```

```text
GET /v1/projects/1/files/plans.txt 200 content-length: 220000 lines=20000
GET /v1/projects/1/files/plans.txt 206 line 00002            Range: bytes=11-20
GET /v1/projects/1/files/plans.txt 416                       Range: bytes=300000-
GET /v1/projects/1/files/plans.txt 304                       If-None-Match: its ETag
GET /v1/projects/1/files/missing.txt 404 {"error":"file_not_found"}
GET /v1/projects/1/files/a%5Cb 400 {"error":"bad_path"}
```

## A paused response

A client that watches a project gets its task count as
[Server-Sent Events](https://html.spec.whatwg.org/multipage/server-sent-events.html),
one every 100 ms, over one response. The client takes each event at once, so `MORE`
can't space them: `rest::pause(cx, ms)` pauses the response, and the case function is
called with `http::TIMEOUT` once `ms` milliseconds have passed, the response still open:

```rust
// GET /v1/projects/:id/progress?n=N: the project's task count as Server-Sent
// Events, PROGRESS_MS apart; N of them, or without N until the client goes.
fn progress(cx, project: i64) {
    let n, given = rest::query_int(cx, "n");
    guard !given || n > 0 else { rest::fail(cx, 400, "invalid_n"); }
    cx.state.left = if given { n } else { -1 };
    rest::begin(cx, 200, "text/event-stream", -1, Use.Progress { project: project });
    progress_event(cx, project);
}

fn resume(u: Use.Progress, cx) {
    guard cx.kind == http::TIMEOUT else { return; }   // CLOSED: the state holds nothing to release
    progress_event(cx, u.project);
}

// Sends the next event, then pauses until the one after, or ends after the
// last.
fn progress_event(cx, project: i64) {
    cx.state.events++;
    rest::send(cx, str("id: ", cx.state.events, "\ndata: {\"tasks\":", count(cx.app.tasks, project), "}\n\n"));
    if cx.state.left > 0 { cx.state.left--; }
    if cx.state.left == 0 { rest::end(cx); } else { rest::pause(cx, PROGRESS_MS); }
}
```

Each call sends an event and pauses again, or ends after the last. The event sent
before a pause goes to the client meanwhile, and no `MORE` comes while the response is
paused. If the client disconnects during a pause, the case function gets `http::CLOSED`,
and goose-http cancels the timer:

```text
GET /v1/projects/2/progress?n=3 200 id: 1 data: {"tasks":2} ... id: 3 data: {"tasks":2}
GET /v1/projects/2/progress?n=0 400 {"error":"invalid_n"}
```

A pause is a wait, so the worker's `http::Config` sets `mail_slots` and `max_waiting`,
as for [work that waits](11-waiting.md):

```rust
    let cfg = http::Config { port: port as i32, workers: 1, mail_slots: 64, max_waiting: 1024, .. };
```

When the worker already holds `max_waiting` waits, goose-http gives `TIMEOUT` at once
([answers that wait](https://github.com/kaitk/goose-http/blob/main/docs/api.md#answers-that-wait)).
goose-rest tells that `TIMEOUT` from the pause's own by its tag, `http::NO_ROOM`, ends the response,
and the case function gets `CLOSED`. A client of Server-Sent Events reconnects to a
stream that ends.

## Which answer to use

| The route has | Use |
|---|---|
| A value that fits in memory | `rest::json`, `rest::text` ([page 3](03-errors.md)) |
| Data it makes as it goes, such as an export | `rest::begin`, `rest::send` at each `MORE`, `rest::end` |
| A file | `rest::file` and `rest::send_file` |
| Events over time, such as Server-Sent Events | `rest::begin`, `rest::send` and `rest::pause` at each `TIMEOUT`, `rest::end` |
| A lane's reply, in pieces | `rest::relay` ([page 12](12-two-lanes.md)) |

A response begun in the route, as both here are, has the CORS fields and `Server-Timing`
in its head. One begun at a later call, such as at a body's `END`, gets the fields the
middleware kept at the request ([page 14](14-bodies-in-pieces.md#middleware-on-later-calls)).

## Compressed

An export is text that compresses well. Begun inside `rest::compressed`, it's sent in the
coding the request's `Accept-Encoding` picks, each `rest::send` compressed as it goes,
and `rest::end` closes the coding. The case function stays as it is: the response keeps
its coding at each `MORE`, outside the block. A download goes as the file is, inside
`compressed` too, so that it keeps its length and its ranges.
[Compression](../reference.md#21-compression) has what's compressed and what each response
holds while it's sent, and
[`examples/compress`](../../examples/compress/main.goose)'s `/v1/export` is an export
compressed this way.

---

[Index](README.md) · Previous: [14. Bodies read as they arrive](14-bodies-in-pieces.md) ·
Next: [16. Testing the application](16-testing.md)
