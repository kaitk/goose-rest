# 06: Resuming a waiting route

Checks the design's [waiting on another thread](../../docs/architecture/README.md#waiting-on-another-thread).
A route asks a database thread over goose-http's mailbox with a job sent as a `to_bytes`
image. It keeps what it needs in a fixed-mode `Waiting` enum in the per-request state,
and resumes at `WAKE` through one case function per variant. Also checks that a missing
case fails to compile, and what a reply larger than a mailbox slot needs.

Goose commit: `46356c2`, with the same output as on `a6249a4`. goose-http: `cb57a0b`, where
the whole 192-byte reply returns `TOO_LONG` rather than `FULL` (2026-10-14), and otherwise
the same output as at `e27ab21`. There `http::Event` is a struct whose `kind` the handler
tests; it was an enum at `04791ac`, where the spike first passed with the same output
(2026-10-13).

- `app.goose`: the handler, `/report` and `/export`, the `Waiting` enum, the `resume`
  case functions, and the database thread.
- `main.goose`: plays the loop's part with real boxes and a real thread, so the output
  is fixed. It hands each request to `app::handle`, takes the worker's box, and calls
  `handle` with `WAKE` for the exchange a message is addressed to, as the loops'
  `delivered` does.
- `server.goose`: the same handler under `http::serve`, for `curl`.
- `missing_case.goose`: case functions with one variant left out.

The programs spawn threads, which TinyCC can't run, so they're built:

```sh
GOOSE=<build>/goose
$GOOSE build -o build/spike06 main.goose && build/spike06
$GOOSE check missing_case.goose           # fails to compile
$GOOSE build -o build/server server.goose && build/server &
curl -i 'localhost:8080/report?org=3&from=1&to=10'
curl --raw -i 'localhost:8080/export?org=7&rows=24'
curl -s 'localhost:8080/export?org=7&rows=2000' | wc -lc
```

## Verdict: works

The route sets `st.waiting`, calls `http::later`, and sends the job, a one-element
array's `to_bytes` image holding the reply's `http::MailAddress`. The database thread
reads it with `from_bytes`, which verifies it, and replies to that address. At `WAKE`,
`resume(st.waiting, st, ev.data, ev.tag, out)` dispatches on the tag to the variant's case
function, which gets the variant's fields by value. A case that must change the state,
as the export's does to count its pieces, writes a new variant into `st.waiting`, which
a fixed-mode enum allows. `main.goose` prints:

```text
-- /report: 1 wake(s), state Report { 3, 1, 10 }
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 48

{"org":3,"from":1,"to":10,"days":10,"total":165}
database: 192 bytes whole: TOO_LONG; in 3 pieces of at most 64
-- /export: 3 wake(s), state Export { 7, 3, 192 }
HTTP/1.1 200 OK
Transfer-Encoding: chunked
Content-Type: text/csv

40
7,0,0
...
7,23,529

0


-- /nothing: 0 wake(s), state Waiting.None
HTTP/1.1 404 Not Found
Content-Type: text/plain
Content-Length: 0
```

`expected.txt` has the whole output. `server.goose` under `http::serve` (kqueue on
macOS, 2026-10-13) answered the same three requests with the same bodies, and
`/export?rows=2000`, 27,427 bytes in 429 pieces through a box of two 64-byte slots,
arrived whole and in order: 2,000 lines.

The state needs no help from goose-http: `S` is any fixed-size struct, and the loop
resets it per request with `x.state = fresh`. A route that never waits leaves
`st.waiting` at `None`, and pays nothing.

## A missing case fails to compile

With `resume` for `Waiting.None` left out, the dispatched call is an error:

```text
missing_case.goose:10: error: no matching overload for call to resume
  candidate resume at missing_case.goose:5: argument 1: cannot pass Waiting as Waiting.Report
  candidate resume at missing_case.goose:6: argument 1: cannot pass Waiting as Waiting.Export
    resume(w);
  in fn main() instantiated from missing_case.goose:8
```

The same in `app.goose` fails the same way at `handle`'s `WAKE` branch. The message doesn't
name the missing variant, where a `match` says `match does not cover variant
Waiting.None` ([findings](../../docs/goose-findings.md#a-case-function-call-missing-a-variant-doesnt-name-it)).

## A reply larger than a slot

A box's slots are fixed when it opens: `Config.mail_slots` of `Config.mail_size` bytes
each, 256 by default. A longer message returns `TOO_LONG` and isn't sent. There is no shared
memory to pass a reference through instead. Two ways work:

- **Bigger slots.** Raise `Config.mail_size` to the largest reply. Each worker's box
  then holds `mail_slots × mail_size` bytes from the start, and every slot pays for the
  largest reply. Fine for replies with a known, small bound.
- **Pieces.** The sender splits the reply into pieces of at most a slot, tagged `MORE`
  until the `LAST`. The handler begins a chunked response at the first `WAKE`, sends each
  piece as a chunk, and calls `http::later` again until `LAST`. `later` keeps the same
  address within an exchange, so the pieces need no new key, and the loop delivers the
  rest of a take to the exchange once `later` has made it wait again. This is what
  `/export` does, and what goose-http's `/events` does for Server-Sent Events.

Pieces need two things from the sender:

- **The slot size.** At `e27ab21`, `FULL` meant either a message longer than a slot or
  no free slot, and nothing gave a sender an address's slot size, so the job carries it
  (`ExportJob.piece`, from the worker's `Config.mail_size`). From `cb57a0b`, a message
  longer than a slot returns `TOO_LONG`, and `http::mail_slot_size(address)` gives the
  size.
- **Backpressure.** The worker's box is shared by all its waiting exchanges, so a
  reply in many pieces fills it. The sender retries a `FULL` piece after 1 ms
  (`sleep_ms`); a database thread serving many workers would rather keep the rest and
  go on with other jobs.

A response of known length can use `http::begin(out, 200, length)` instead of chunked,
with the length in the first piece.

Recommended for task 009: `rest::ask` takes pieces, with the slot size in the job and
the chunked response written by the framework, so a reply of any size works. A program
whose replies all fit raises `Config.mail_size` and never sees a second piece.
