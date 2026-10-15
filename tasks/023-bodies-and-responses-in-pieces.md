# 023: Read a body and send a response in pieces

Status: built (2026-10-15); instruction counts open (found 2026-10-15; proposal agreed
2026-10-15)

`rest::receive`, as the proposal below names it, is `rest::body_in_pieces` (2026-10-15):
"receive" read as if the call read the body, where it only accepts it and says where its
pieces go. Rocket's `Data::open(limit)`, axum's `into_data_stream`, actix-web's
`Payload`, and http.zig's `req.reader()` hand the handler a stream to pull from, which
Goose can't keep, so a stream or reader name would mislead; the name pairs with
`rest::body`, which gathers the body whole.

goose-rest gathers a request body whole, up to its limit (`rest::body`), and sends a
response whole, but for `rest::relay`'s pieces of a service's reply. A route can't read
an attachment of any size as it arrives, or send an export, a file, or events in pieces
as the loop takes them, though goose-http does all of these
([patterns](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md), "Request
bodies" and "Long responses"). The tutorial lists its pages 11, "Bodies read as they
arrive", and 12, "Long responses and files", as TBD until this lands (task 016), and the
README's status table names both as not yet.

An upgraded connection has the same gap. A program can take one today only by running
`http::serve` itself with `rest::Slot<St>` and calling `rest::on_event` for every event
but its upgraded connections' (built and checked on 2026-10-15: a 101, then raw bytes
echoed). Under `rest::serve` the client's bytes after `http::upgrade` are dropped,
because `on_event` passes `BODY` on only to a body being gathered.

## Proposal (2026-10-15)

Agreed (2026-10-15), with the open questions answered at the end.

### 1. One resume mechanism: the `Waiting` enum, for every later call

Today the handler is called at `REQUEST`, at a service's `WAKE`, and once more at the
`END` of a body `rest::body` gathered. Proposed: a route that reads in pieces, sends in
pieces, or upgrades says so with a call that takes a `Waiting` variant, as `rest::ask`
does, and `rest::serve` calls the handler again for each event of that exchange, with
`cx.kind` saying which. The program's handler keeps its one branch:

```rust
rest::serve(cfg, app, St { .. }) { cx =>
    if rest::resumed(cx) { rest::route(cx) { resume(cx.state.waiting, cx); }; } else { handle(cx); }
};
```

| The route called | The case function is called with `cx.kind` | goose-rest itself handles |
|---|---|---|
| `rest::ask` (as today) | `http::WAKE` | `TIMEOUT`: 504 |
| `rest::receive` | `http::BODY` per piece, then `http::END`; `http::CLOSED` | the limit: 413 |
| `rest::begin` | `http::MORE`, `http::TIMEOUT`, `http::CLOSED` | a `HEAD` request: no calls |
| `rest::upgrade` | `http::BODY` per arrival; `http::CLOSED` | |
| `rest::file` | none | `MORE` and `CLOSED`, through `http::send_file` |
| `rest::relay` (as today) | none | the reply's later pieces |

Decisions:

- **One case function per variant handles every kind**, and tests `cx.kind`. The
  variants a route uses are few, and each variant's function reads as the route's second
  half. `cx.body` holds a `BODY` piece; `cx.req` is empty after `REQUEST`, as at `WAKE`
  today, so a variant carries what of the request it needs.
- **`Waiting` and `resume` stay.** They're the program's names, used by the reference and
  pages 13 to 15; a route reading the next piece is waiting for it.
- **`rest::woken` becomes `rest::resumed`**: true for every call after a request's
  first, `kind != http::REQUEST`. A program that only asks behaves as before. A body
  gathered by `rest::body` still reruns the handler with `kind` `REQUEST`, as today.
- **`CLOSED` means "ended before the route finished; release what the state holds"**,
  and comes once, to a route that called `receive`, `begin`, or `upgrade`: when its
  client goes, when it passes its limit, when it answers or fails before the body's
  `END`, or when it fails with its response open. A route that ends normally, answering
  at `END` or calling `rest::end`, gets no `CLOSED`. A route that only asked gets none,
  as today, so no existing case function sees a new kind.
- **Progress goes in the per-request state's own fields**, such as bytes so far or a
  file's path. A case function gets its variant by value (spec §8.2, a fixed-mode
  enum), so it changes the variant only by writing a new one.

Rejected:

- **A case-function name per kind** (`on_piece`, `on_end`, `on_more`, `on_closed`).
  §8.2 needs an overload for every variant under each name, so an enum of five variants
  needs twenty functions, most of them empty. A generic fallback doesn't help: checked
  with a throwaway program on `v2026.1`, `fn on_closed(w, n)` beside
  `fn on_closed(w: Waiting.Upload, n)` takes the whole enum, and the call never
  dispatches, for every variant, `Upload` included, without an error.
- **A block per call**, as `rest::receive(cx, limit) { piece => ... }`. Goose can't keep
  a block to call at the next event (spec §7.6); for a body that's whole at once, it's
  `rest::body`.
- **`rest::serve` dispatching the case functions itself.** It works: checked on
  `v2026.1`, a generic function in one namespace dispatches on the program's enum when
  the program declares its case functions as `fn lib::resume(w: Waiting.Upload, cx)`
  (spike 01's form). But every program, those without a `Waiting` field included, would
  then need one, and the case functions move into goose-rest's namespace, to save the
  program one line.
- **A second enum for pieces** beside `Waiting`: a route that receives and then asks a
  service would need both, and two dispatches.
- **The program on `http::serve` with `rest::on_event`**, as checked for upgrades: it
  stays possible, but those exchanges leave `rest::route`, `fail`, and the error shape.

### 2. Reading in pieces: `rest::receive`

```rust
// Sketch, not compiled.
enum Waiting { None, Attachment { project: i64 } }
struct St { waiting: Waiting = Waiting.None, path: u8[..128] = [], size: i64 = 0 }

let ATTACHMENT_LIMIT: i64 = 1 << 30;   // Config.max_body raised to it

// POST /v1/projects/:id/attachments: any size, held a piece at a time.
fn attach(cx, project: i64) {
    format(cx.state.path, "attachments/", project, "-", now_ms(), ".part");
    rest::receive(cx, ATTACHMENT_LIMIT, Waiting.Attachment { project: project });
}

fn resume(w: Waiting.Attachment, cx) {
    if cx.kind == http::BODY {
        guard append_file(cx.state.path, cx.body) else { rest::fail(cx, 500, "not_stored"); }
        cx.state.size += cx.body.len;
    } else if cx.kind == http::END {
        rest::json(cx, 201, Attached { project: w.project, size: cx.state.size });
    } else {
        delete_file(cx.state.path);   // CLOSED: gone, past the limit, or failed above
    }
}
```

- `rest::receive(cx, limit, w)` sets `cx.state.waiting = w` and leaves the route without
  an answer; the code before it runs once, unlike `rest::body`'s. A body that came whole
  with its head goes to the case function too: after the handler returns, `on_event`
  calls it with the whole body as one `BODY`, then `END`, so a route has one path for
  every size. An empty body gets `END` alone.
- **Limit.** A `Content-Length` over `limit` fails at `receive` with 413
  `payload_too_large`, before the client sends the body, as `rest::body` does. A chunked
  body is counted as it comes; past `limit`, goose-rest answers 413 itself, closes the
  connection as `http::body_within` does, and calls the case function with `CLOSED`.
  `Config.max_body` still caps every route with goose-http's own 413, so a program
  raises it to its largest limit, as page 10 says.
- **Failure mid-body.** `rest::fail` from a `BODY` call answers at once, in the error
  shape. goose-rest then calls the case function with `CLOSED`, writing nowhere, and
  passes it no more pieces. goose-http drops the rest of the body up to
  `Config.max_drain` and keeps the connection, or closes it past that
  ([patterns](https://github.com/kaitk/goose-http/blob/main/docs/patterns.md#request-bodies)).
  An answer at `BODY` that isn't a failure ends the read the same way: goose-http
  allows one answer per request. A route that begins its response with `rest::begin`
  while it reads keeps getting pieces, as an echo or a transform needs.
- **`rest::body` and `rest::receive`.** A request's first call decides: the other then
  fails with 500. `receive` doesn't gather, so the "runs twice" rule is only
  `rest::body`'s.
- **Middleware.** `timed` and `cors` run around `handle`, at `REQUEST`, not around
  `resume`. An answer written at `END` therefore has no CORS fields and no
  `Server-Timing`, which is already so for an answer at `WAKE` (reference, "Middleware").
  This matters for a browser uploading cross-origin; fixing it for every later call is
  separate work (open question 4).
- **Multipart.** No new API: the case function calls goose-http's `each_part` on each
  piece, with an `http::Multipart` in the state, started with `http::start_multipart` at
  the route (415 when it isn't one) and checked with `http::multipart_done` at `END`
  (400). A `rest::each_part(cx, m) { part => }` that fails with 400 `invalid_multipart`
  is a small later addition, if the tier D server or page 11 shows the error shape is
  missed.

### 3. Sending in pieces: `rest::begin`, `send`, `end`, and `rest::file`

```rust
// Sketch, not compiled.
// GET /v1/projects/:id/tasks.csv: 500 tasks at each MORE.
fn export(cx, project: i64) {
    cx.state.next = 0;
    rest::begin(cx, 200, "text/csv; charset=utf-8", -1, Waiting.Export { project: project });
}

fn resume(w: Waiting.Export, cx) {
    guard cx.kind == http::MORE else { return; }   // CLOSED: nothing held
    var piece: u8[>..] = [];
    cx.state.next = tasks_csv(piece, cx.app, w.project, cx.state.next, 500);
    rest::send(cx, piece);
    if cx.state.next < 0 { rest::end(cx); }
}

// GET /v1/projects/:id/files/*name: 304, 206, and 416 as http::serve_file answers.
fn download(cx, project: i64) {
    var path: u8[>..] = [];
    guard http::file_path(dir_of(project), rest::param(cx, "name"), path) else {
        rest::fail(cx, 400, "bad_path");
    }
    rest::file(cx, path);   // 404 file_not_found, 403 forbidden
}
```

- `rest::begin(cx, status, content_type, length, w)` is `http::begin` and its
  `Content-Type`, sets `w`, and asks for `MORE`; `length` -1 is chunked. For `HEAD` it
  ends the response at once and asks for nothing. `rest::send` and `rest::end` are
  `http::send` and `http::end` on `cx.out`. Backpressure is goose-http's: `MORE` comes
  only while the client takes what it's sent, and a piece of about 16 KB per `MORE`, as
  goose-http's `compress/` sends, keeps within `Config.max_queued`.
- A response begun at `REQUEST` gets the CORS fields and `Server-Timing` in its head,
  since `begin` runs inside the middleware. One begun later, such as at `END`, gets
  neither.
- **Failure with the response open.** The first answer wins (architecture, "Handlers"),
  and the head has gone. Proposed: `rest::route` writes no error into an open response.
  It leaves the response unended, which makes goose-http close the connection, so the
  client sees it cut short. The case function then gets `CLOSED`. Today `route` would
  write the error into an open response that an earlier call began.
- **`TIMEOUT`** goes to the case function of a route that began a response, so that it
  can send an event each interval with `http::later(cx.out, ms)`, as goose-http's
  `device/` does. One that ignores it writes nothing, and goose-http closes the
  connection, which is what happens to a late `relay` today.
- **Files go through goose-rest, with no case function.** `rest::file(cx, path,
  content_type = "")` opens the file, fails with 404 `file_not_found` or 403 `forbidden`
  in the error shape, answers with `http::serve_file`, and keeps the `http::FileBody` in
  goose-rest's per-request slot. `on_event` then calls `http::send_file` at each `MORE`
  and `http::close_body` at `CLOSED`, as it relays a reply's pieces today. A program
  can't leak a file by forgetting a `CLOSED` branch. The cost is 24 bytes more in the
  slot that goose-http starts from fresh for every request (section 5); if that shows
  up in instruction counts, the `FileBody` moves into the program's state and a
  `Waiting` variant, as generated data has.
- **`rest::relay` is unchanged.** Under `rest::begin`, a service's reply in pieces goes
  to the case function piece by piece, not through `relay`, which would end the route's
  response at the last piece.

### 4. Upgrade: `rest::upgrade`

```rust
// Sketch, not compiled.
fn echo(cx) {
    guard http::upgrade_of(cx.req) == "echo" else { rest::fail(cx, 426, "upgrade_required"); }
    rest::upgrade(cx, "echo", Waiting.Echo);
}

fn resume(w: Waiting.Echo, cx) {
    if cx.kind == http::BODY { rest::send(cx, cx.body); }   // rest::end closes the connection
}
```

`rest::upgrade(cx, protocol, w)` is `http::upgrade`, and sets `w`. goose-http then passes
the client's bytes as `BODY`, with no `END`, no `MORE`, and no body limit, and `CLOSED`
when either side closes. `rest::send` writes bytes as they are. A WebSocket's framing
stays out of scope (README); a package on top of this can provide it. One limit is
goose-http's: while an exchange waits with `http::later`, its loop doesn't read the
connection, so an upgraded connection that asks a service gets no client bytes until
the reply. That's for goose-http to change, if a program needs both at once.

### 5. Cost for programs that use none of this

goose-rest's bookkeeping for a request, today's `Gather` in `Slot<S>`, becomes the
exchange's: `pending: bool` becomes `mode: u8`, a bit each for gathering, receiving,
sending, upgraded, and a file, and receiving reuses `limit` and `len` as its limit and
bytes so far. Only the `FileBody` adds bytes (section 3). In `on_event`:

- At `REQUEST`, nothing new: `mode` is set where `pending` is, and the one test after
  the handler, `pending && limit > 0` today, becomes `mode != 0`.
- The other branches test `mode` where they test `limit > 0` today, plus one test at
  `TIMEOUT` and one on a reply's later pieces.
- The new calls to the handler (pieces, the whole-body `BODY` and `END`, `CLOSED` with
  a reply that writes nowhere) go through one function that isn't `inline`. `on_event`
  is `inline`, and the handler is inlined at each of its call sites: a call site per
  kind would copy the program's whole handler into the request path several times.

Measured before the change and after each step, on the machine and under the rules of
`docs/benchmarks.md`:

- `scripts/test.sh`'s `test/inline_route.goose` C check, unchanged, plus a check that
  the request path's function holds one copy of the handler and the new calls stay out
  of line.
- `bench/rest.sh count`, instructions per request, on tiers A and M at least: expected
  unchanged but for the `FileBody`'s copy. A rise past run-to-run noise is explained or
  undone before the step lands.
- The size of the tier server's text section, for the handler's second instance.
- Tier D, once its server reads its CSV and multipart bodies with `rest::receive`
  rather than gathering up to 16 MB: memory and req/s, against goose-http's tier D.

### 6. Compression

The compression module another agent is building (`rest.compression`) meets this in
three places. A response in pieces keeps an `http::Compressed` across `MORE` calls; the
type is defined only when goose-http's `http.compression` is imported, so it lives in the
program's state, not goose-rest's slot. The module then needs its own `begin`, `send`,
and `end`, as goose-http's `begin_compressed`, `send_compressed`, and
`end_compressed`, since `rest::send` can't know about an encoder. And its case function's
`CLOSED` must call `http::release_compressed`, or the worker's encoder pool keeps the
slot. `rest::file` can take a file from `http::open_precompressed`. Only flagged here.

### 7. The tutorial's pages

**11. Bodies read as they arrive.** The projects get attachments of any size, up to
1 GB, which no worker could hold whole. `POST /v1/projects/:id/attachments` checks the
project and calls `rest::receive`; the case function appends each piece to a `.part`
file, renames it and answers 201 with its size at `END`, and deletes it at `CLOSED`.
The requests show a small attachment, which comes whole, a large one in many pieces, a
404 before anything is read, a 413 from a `Content-Length` over the limit, and a client
that hangs up midway, whose `.part` file is gone. Then a multipart form of a note and a
file through `each_part`. It links goose-http's request bodies.

**12. Long responses and files.** A project's tasks exported as CSV, 500 rows each time
the loop calls with `MORE`, so that the worker holds one piece however many tasks there
are, and a slow client gets no more until it reads. Then an attachment downloaded with
`rest::file`, with a 304 for a matching `If-None-Match` and a 206 for a range. The page
ends with when to pick which: `rest::json` for what fits, `rest::begin` for data made as
it goes, `rest::file` for a file, and `rest::relay` (page 14) for a service's reply. It
links goose-http's long responses.

### 8. Build plan

Each step is its own commit, with its tests, and `scripts/test.sh` passing.

1. Record the baseline: `bench/rest.sh count` and the text section size, at the commit
   before step 2.
2. `Gather` becomes the exchange's bookkeeping with `mode`; `rest::woken` becomes
   `rest::resumed` across the pages, tests, and reference; the out-of-line call for
   later events; `rest::route`'s rule for an open response. No behaviour changes; counts
   compared.
3. `rest::receive`, its limit, failure mid-body, and `CLOSED`. `rest::serve_one` already
   passes a long body in pieces; it gains a way to end a request early, as a client that
   hangs up. Tests: whole and in pieces, 413 by length, failure mid-body, a hang-up.
4. `rest::begin`, `send`, `end`, `MORE`, and `TIMEOUT`. `serve_one` calls with `MORE`
   until the response ends. Tests: chunked and with a length, `HEAD`, a failure with the
   response open.
5. `rest::file`, with the `FileBody` in the slot. Counts compared; the fallback in
   section 3 if they rise.
6. `rest::upgrade`, tested with a real socket, since `serve_one` reads one response.
7. Pages 11 and 12 with programs and `requests.sh`; the index; page 10's last paragraph
   and page 14's end of "A reply in pieces", which say goose-rest can't do this yet.
8. Docs: the architecture's "Waiting on another thread" (every later call, not only a
   reply, goes through the case functions; dated decision) and "Inlining" (the
   out-of-line call); the reference (the calls, `CLOSED`, the 413 and 500, and
   `rest::resumed`); the README's rows "Bodies in pieces" and "Static files, streaming",
   and "WebSocket", which says upgraded connections reach the route; `CHANGELOG.md`.
9. Optional: tier D's server on `rest::receive`, measured (section 5).

### Open questions, answered (2026-10-15)

The proposal and its build plan are agreed, with these answers:

1. `rest::woken` is renamed to `rest::resumed`, and the tutorial's pages that call it
   change with it: once it covers pieces and `MORE`, "woken" no longer says what it is.
2. The file body lives in the program's state, with a `Waiting` variant, so that
   programs that serve no files pay nothing (AGENTS.md, "Benchmarks"). Section 3's slot
   field goes; `rest::file` takes the `http::FileBody` the program keeps.
3. `TIMEOUT` to a route that began a response, for events over time, is left to a later
   task; pages 11 and 12 don't need it.
4. CORS fields and `Server-Timing` on answers written after `REQUEST` are task 025, of
   their own and next after this one: a cross-origin upload that page 11 shows needs
   them.
5. `rest::send` and `rest::end` are thin wrappers, so that a route stays in `rest::`
   calls and the compression module can offer its own for responses in pieces.

## Acceptance criteria

- [x] The proposal is agreed, with the open questions answered (2026-10-15)
- [x] A route reads a body in pieces as they arrive, with a limit, inside `rest::route`,
      and gets `CLOSED` once when it ends early
- [x] A route sends a response in pieces as the loop calls for more, and a file
- [x] A route takes an upgraded connection's bytes under `rest::serve`
- [ ] Instruction counts of tiers A and M and the inlining checks show no change for a
      program that uses none of this, or the change is recorded and agreed
- [x] The tutorial's pages 11 and 12, each with a program `scripts/test.sh` builds and
      requests, and the index links them
- [x] The architecture doc, the reference, and the README's status rows say what works

## Built (2026-10-15)

Built as proposed, with these differences found on the way:

- `rest::send_file(cx, body)` is the case function's one call for a file: the file body
  lives in the program's state (answer 2), so goose-rest can't send it on its own.
- `on_later`, the function for the later calls, isn't kept out of line: Goose inlines a
  function called once, and goose-http calls `serve`'s block once in each of its places,
  so it lands in each, the request path's included
  ([findings](../docs/goose-findings.md#a-function-called-once-cant-be-kept-out-of-line)).
  The handler's calls per function are as before: in `bench/rest/goose-rest`'s server,
  two in each `http::answer` (the request path), before and after, and 54 in all; the
  second copy was the gathered body's before, and is `on_later`'s now.
- The request path's C changes only by the test after the handler: `mode != 0` for
  `pending && limit > 0`, compared with `-O2 -o` on `examples/plain`, `examples/schema`,
  `test/inline_route.goose`, the tutorial's pages 10 and 13, and the tier server, on an
  Apple M1 Pro, macOS 26 (Darwin 25.3.0), Goose `v2026.1`. `inline_route`'s check
  passes, and its C differs only in names and in `rest::route`'s failure branch, which
  now cuts an open response short. The calls added in steps 3 to 6 change no program
  that doesn't use them: the C is the same apart from an error code's string.
- Not measured: `bench/rest.sh count` needs Linux's perf counters. To close the open
  criterion, run it on the machine of `docs/benchmarks.md`, at the commit before this
  task's first and at its last, for tiers A and M, and compare the text section's size.
- Left open: `rest.compression` doesn't compress a response sent in pieces (section 6:
  its own `begin`, `send`, and `end`, with the `http::Compressed` in the program's
  state); `TIMEOUT` to a route that began a response (answer 3); `rest::file` from
  `http::open_precompressed`; tier D's server on `rest::receive` (step 9).
