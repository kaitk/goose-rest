# 10: One enum for a route's use cases

Checks task 050's proposal on `docs/best-practices/lanes/`'s program: one fixed-mode
enum, `Use`, whose variant is both the job a lane runs and what the route waits with in
`cx.state`. A lane dispatches the job to `run` case functions, the worker resumes
through `resume` case functions, and a job that fails replies its failure, which fails
the route before its `resume` runs. It answers the task's three questions: whether
replies of different types dispatch, how much the request state grows, and whether the
`::resume` forwarders go.

- `main.goose`, `app.goose`, `entries.goose`, `reports.goose`, `auth.goose`: the lanes
  program's four use cases on the package, with the calls of `proposal.goose`. `main`
  plays goose-http's loop, as spikes 06 and 09 do, with three real lanes.
- `proposal.goose`: the calls the package would take, in namespace `spike10` beside
  the package's `rest`: `ask` with a variant, `lane`, `reply_value`, `on_reply`, and
  `answer`. They were in namespace `rest` until the package took spike 11's calls of
  the same names (2026-10-19), with the same output.
- `sizes/main.goose`: the request state, and a connection's bytes, with each enum.
- `cases/main.goose`: replies of different types through a block, and an overload
  that hides dispatch.
- `differing_replies.goose`, `lane_types.goose`, `split_set.goose`,
  `unqualified.goose`: what fails to compile.

Goose: commit `f114b5a`, the pin, with the same output as on `dcc2747`. goose-http: `cbffc2a`, with the same output as at `5701a0d`, `b5f82a2`, `v0.4.3`, `v0.4.2`, `v0.4.1`, `v0.4.0`, and `ff18ecc`.

```sh
GOOSE=<build>/goose
$GOOSE build -o ../../build/spike10 main.goose && ../../build/spike10
$GOOSE sizes/main.goose
$GOOSE cases/main.goose
$GOOSE check differing_replies.goose   # each of the four fails to compile
```

## Verdict: works

A route that waits costs four pieces in two files, down from nine in four: a variant
of `Use` in `app.goose`, and the route, its `run`, and its `resume` in its domain's
file. The tags, the job structs, the lane's if chain, the `::resume` forwarders, and
the `guard ok else { rest::fail(cx, 502, "bad_reply"); }` of every `resume` go:

```rust
// app.goose
enum Use {
    None,
    EntryCreate { project: i64, started: i64, stopped: i64 },   // entries::create
    ...
}
struct St { use: Use = Use.None }

// entries.goose, in namespace entries
fn create(cx) {
    ...
    spike10::ask(cx, cx.app.writer, Use.EntryCreate { project: project, started: started, stopped: stopped });
}

fn ::run(u: Use.EntryCreate, db: Db&, a) {
    entries::check(entries::ordered(u.started, u.stopped), a);
    let e = entries::Entry { id: db.entries.len + 1, project: u.project, started: u.started, stopped: u.stopped };
    db.entries.push(e);
    spike10::reply_value(a, e);
}

fn ::resume(u: Use.EntryCreate, cx) { rest::json(cx, 201, spike10::answer<entries::Entry>(cx)); }
```

Each program writes, once, a `run` and a `resume` for `Use.None`, one lane thread for
every lane, and `spike10::on_reply` in place of `rest::route` at a later call:

```rust
thread_fn lane(box: http::Box) {
    ...
    var db = Db { entries: all, sessions: sessions };
    spike10::lane<Use>(box) { u, a => run(u, db, a); };
}

rest::serve(cfg, app, St { .. }) { cx =>
    if rest::resumed(cx) { spike10::on_reply(cx) { resume(cx.state.use, cx); }; } else { handle(cx); }
};
```

`main.goose` prints, for each request, the variant the route waits with at each reply,
and whether its job failed:

```text
-- POST /entries?project=1&started=1767254400&stopped=1767250800
  wake: EntryCreate { 1, 1767254400, 1767250800 }, job failed
  422 Unprocessable Content {"error":"entry_ends_before_start"}
...
-- POST /auth/session?email=ada@example.com&password=goose
  wake: AuthPassword { "ada@example.com", "goose" }
  wake: AuthSession { 1 }
  201 Created {"session":1,"user":1}
```

`expected.txt` has the whole output. The design has two constraints, below: every lane
takes one state type, and the request state grows to the largest job.

## Replies of different types: each run sends its own

§8.2 requires the case functions' return types to agree, so `run` can't return replies
of different types (`differing_replies.goose`):

```text
differing_replies.goose:13: error: case functions of run disagree on return types: Totals vs bool
    run(u);
  in fn main() instantiated from differing_replies.goose:11
```

Two shapes work:

- **Each `run` sends its reply**: `spike10::reply_value(a, v)`, where `a` is the job as it
  crossed, with its reply address. Every `run` returns nothing, so they agree. This is
  what `main.goose` does, and what the lanes' code does today.
- **Each `run` hands its reply to a block**: `fn run<F>(u: Use.Report) { F(totals); }`,
  called as `run(u) { v => spike10::reply_value(a, v); }`. Goose instantiates the block for
  each case's type (`cases/main.goose`). This keeps the reply address out of `run`, so a
  test can call `run` and check what it hands over, but every `run` writes `F(...)`
  where the other shape names the reply.

Recommended: each `run` sends its reply. It reads as what it does.

The job crosses as the enum itself. `spike10::ask` stores the variant in `cx.state.use`
and sends an `Ask<Use>` built from that field, since a variant's constructor
(`Use.EntryCreate { ... }`) has the variant's type, which would make an `Ask` of the
variant. The image is a fixed 157 bytes for every job, from `http::lane_send_value`;
the lane reads it with `http::mail_value` into a `rest::Ask<Use>`, whose `from_bytes` checks the tag, and
dispatches on it. `LaneConfig.size` must hold the largest variant's image: a longer one
returns `TOO_LONG`, which `ask` answers as 503.

### Every lane takes one state type

A lane's dispatched call needs a case for every variant with that lane's arguments. If
each lane's `run` took its own state type, the writer's `run(u, w)` would need a case
for the report too, typed for a `Writer` (`lane_types.goose`):

```text
lane_types.goose:15: error: no matching overload for call to run
  candidate run at lane_types.goose:8: argument 1: cannot pass Use as Use.None
  candidate run at lane_types.goose:9: argument 1: cannot pass Use as Use.Create
  candidate run at lane_types.goose:10: argument 1: cannot pass Use as Use.Report
```

So every lane's thread holds the same `Db`, here the writer's tables, which the other
lanes hold empty; in a program on a database, each thread's connection. All three
lanes then run one `thread_fn`. Nothing checks which lane a job goes to: a write sent to
the reports lane compiles and runs on a reader. The lane is named at the `ask`, as now.

A catch-all for the variants a lane doesn't run doesn't work either. An overload that
takes the whole enum is an exact match, so a call with a `Use` takes it for every
variant, and the variant's own case never runs (`cases/main.goose`: `rows taken by the
Report case: 0`).

A route that waits on its own body (`rest::body_in_pieces`) or on a pause, not a lane,
has a variant too, so each lane's dispatch needs a `run` for it that does nothing.

## An error a job returns fails the route

A `run` fails as a route does: `rest::fail(a, 422, "entry_ends_before_start")` is a
`return ... from rest::attempt`, which `spike10::lane` wraps around the dispatch. `fail`
ignores its first argument, so a domain's `check(e, x)` serves a route's `cx` and a
lane's `a` unchanged. `spike10::lane` replies the failure as a `Refusal { status, code }`
with the tag `JOB_FAILED`, and `spike10::on_reply` fails the route with it before the
`resume` runs. A `run` that can fail doesn't compile when called outside `spike10::lane` or
`rest::attempt`.

The reply is a fixed struct, not `rest::Failure`: its owned `u8[]` fields make it
variable-size, and `http::mail_value` indexes the image's array, which Goose refuses for
variable-size elements. `JOB_FAILED` is the bit the package gives `REPLY_REFUSED`,
beside `REPLY_MORE` and `REPLY_CONT`, so that the package's `cx.refused` says it.

`spike10::answer<T>(cx)` replaces `read_reply` and its guard: it fails the route with 502
`bad_reply` for a reply that isn't a `T`.

## The request state grows to the largest job

The variant waits in `cx.state`, so the state takes a tag and the largest job's
payload. `sizes/main.goose`, in bytes (`expected.txt` there):

| Request state | State | `rest::Slot` | goose-http's `RingConn` |
|---|---:|---:|---:|
| Tier M (`rest::NoState`) | 1 | 59 | 242 |
| Tiers C and D (`Heavy`) | 9 | 67 | 250 |
| The lanes, `Waiting` | 1 | 59 | 242 |
| The lanes, `Use` | 131 | 189 | 372 |
| The lanes, `Use` without the sign-in | 25 | 83 | 266 |

The `Slot`s are 8 bytes larger than when the spike ran, for the promise in the
`http::Gather` that `rest::Exchange` holds from 2026-10-22.

The sign-in's two `u8[..64]` fields, 65 bytes each, make 130 of the 131. With ids
alone, the largest job is three `i64`s, and a connection grows by 24 bytes, 10%. With
the sign-in's text, it grows by 130 bytes, 54%: 130 KB per 1,000 connections, or 8 KB
for a worker's share of the benchmark's 256 connections. A program pays this only when
it waits: tier M has no `Use`, and its state stays one byte.

Two costs follow:

- goose-http resets the state from `fresh` for each request, so the reset copies the
  whole `Slot`, 189 bytes in place of 59. Not measured.
- A job's input stays in the connection's state until the route waits again or the
  next request resets it: here, the password. The package should set `cx.state.use`
  back to `None` once the route has answered.

Recommended: keep variants to ids and short fixed fields, and size a text field for
what the job needs.

## The forwarders go: case functions declared in the global namespace

Overload sets don't merge across namespaces (§11.1), so a `resume` declared in namespace
`reports` isn't a candidate for the dispatch in the global namespace, and the call
lacks a case (`split_set.goose`):

```text
split_set.goose:10: error: no matching overload for call to resume
  candidate resume at split_set.goose:5: argument 1: cannot pass Use as Use.None
    resume(u);
```

The domain's file can declare its case functions in the global namespace itself, as
`fn ::run(...)` and `fn ::resume(...)`. A declaration's qualifier decides the namespace
of the names inside it too (§11.1), so the body resolves names globally, and the
domain's own helpers need their namespace (`unqualified.goose`):

```text
unqualified.goose:11: error: unknown function: total
fn ::resume(u: Use.Report) { total(u.project); }
```

With `reports::totals`, `entries::check`, and the like, `entries.goose`,
`reports.goose`, and `auth.goose` declare their cases beside their routes, and no
forwarder remains. A `format` overload is still found from there, since the `format`
hook looks by type (§3.7).

The other ways cost more: a forwarder per case, as now, or a file without a namespace
for the domain's cases, which still qualifies the domain's names and moves the cases
away from their routes. Recommended: `fn ::run` and `fn ::resume` in
the domain's file.

The error when a case is missing still doesn't name the variant
([findings](../../docs/goose-findings.md#a-case-function-call-missing-a-variant-doesnt-name-it)).
