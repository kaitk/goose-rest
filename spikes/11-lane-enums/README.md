# 11: One enum per lane

Checks spike 10's shape with an enum per lane in place of one `Use` for the program, on
the same four use cases of `docs/best-practices/lanes/`. Each lane takes its own enum
of jobs (`Writes`, `Reports`, `Hashes`), its own state, and `run` cases for its own
variants only. It answers spike 10's three catches: every lane took one state type and
nothing checked which lane a job went to, a catch-all `run` hid dispatch, and the job's
inputs stayed in the request state, which grew to the largest job.

- `main.goose`, `app.goose`, `entries.goose`, `reports.goose`, `auth.goose`: the four
  use cases on the package, with the package's calls. `main` plays
  goose-http's loop, as spike 10's does, with three real lanes, each its own
  `thread_fn`.
- The calls, `Lane<U, M>`, `lane_open`, `ask`, `lane`, `done`, `on_reply`, `job`, and
  `answer`, were a `proposal.goose` in namespace `rest` beside the package's own. The
  package took them for task 050 (2026-10-19), `done` as `plod::reply_value` and the
  refusal's tag as `plod::REPLY_REFUSED`, and the programs here use the package's,
  with the same output.
- `wrong_lane.goose`: a report's job sent to the writer lane, which fails to compile.
- `outer/main.goose`: the other way to hold the wait, an outer enum holding each lane's
  job.
- `catch_all/main.goose`: a catch-all `run` beside one lane's cases.
- `sizes/main.goose`: the request state with each shape, beside spike 10's.

Goose: commit `f114b5a`, the pin, with the same output as on `dcc2747`. goose-http: `ebb4238`, with the same output as at `v0.5.4`, `v0.5.3`, `v0.5.2`, `cbffc2a`, `5701a0d`, `b5f82a2`, `v0.4.3`, `v0.4.2`, `v0.4.1`, `v0.4.0`, and `ff18ecc`.

```sh
GOOSE=<build>/goose
$GOOSE build -o ../../build/spike11 main.goose && ../../build/spike11
$GOOSE outer/main.goose
$GOOSE catch_all/main.goose
$GOOSE sizes/main.goose
$GOOSE check wrong_lane.goose   # fails to compile, with the errors its first lines name
```

## Verdict: works, and replaces spike 10's shape

A route that waits still costs four pieces in two files: a variant of its lane's enum
in `app.goose`, and the route, its `run`, and its `resume` in its domain's file. A job
sent to the wrong lane no longer compiles, each lane's `run` takes that lane's own
state, and the request state holds one byte, the lane's mark, as tier M's does. The
job's inputs never sit in the request state: they cross in the mail, and the lane's
reply carries the job back for `resume`. The cost is three lines per lane in
`app.goose`, and the job's bytes once more in each reply.

Recommended: this shape for task 050, with `plod::done` folded into `plod::reply_value`
and the echo skipped by `plod::relay` (below).

```rust
// app.goose
enum Writes {
    EntryCreate { project: i64, started: i64, stopped: i64 },   // entries::create
    AuthSession { user: i64 },                                  // auth::sign_in, after the password
}
enum Reports { ReportTotals { project: i64 } }                  // reports::project
enum Hashes { AuthPassword { email: u8[..64], password: u8[..64] } }   // auth::sign_in

enum Use { None, Write, Report, Hash }
struct St { use: Use = Use.None }

struct App { writer: plod::Lane<Writes, Use>, reports: plod::Lane<Reports, Use>, hasher: plod::Lane<Hashes, Use> }

fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Write, cx) { resume(plod::job<Writes>(cx), cx); }
fn resume(u: Use.Report, cx) { resume(plod::job<Reports>(cx), cx); }
fn resume(u: Use.Hash, cx) { resume(plod::job<Hashes>(cx), cx); }

// entries.goose, in namespace entries
fn create(cx) {
    ...
    plod::ask(cx, cx.app.writer, Writes.EntryCreate { project: project, started: started, stopped: stopped });
}

fn ::run(u: Writes.EntryCreate, w: Writer&, a) {
    entries::check(entries::ordered(u.started, u.stopped), a);
    let e = entries::Entry { id: w.entries.len + 1, project: u.project, started: u.started, stopped: u.stopped };
    w.entries.push(e);
    plod::done(a, e);
}

fn ::resume(u: Writes.EntryCreate, cx) { plod::json(cx, 201, plod::answer<entries::Entry>(cx)); }

// main.goose: a thread per lane, each with its own state
thread_fn reader(box: http::Box) {
    var r = Reader { entries: reports::ENTRIES };
    plod::lane<Reports>(box) { u, a => run(u, r, a); };
}

var a = App {
    writer: plod::lane_open<Writes>(http::LaneConfig { slots: 16, .. }, Use.Write, writer),
    ...
};
plod::serve(cfg, a, St { .. }) { cx =>
    if plod::resumed(cx) { plod::on_reply(cx) { resume(cx.state.use, cx); }; } else { handle(cx); }
};
```

`main.goose` prints, for each request, the mark the route waits with and the job the
reply carries back at each wake, then the request state once the route has answered:

```text
-- POST /auth/session?email=ada@example.com&password=goose
  wake: Use.Hash AuthPassword { "ada@example.com", "goose" }
  wake: Use.Write AuthSession { 1 }
  201 Created {"session":1,"user":1}
  then: Use.Write
-- POST /auth/session?email=ada@example.com&password=gander
  wake: Use.Hash, job failed
  401 Unauthorized {"error":"invalid_credentials"}
  then: Use.Hash
```

`expected.txt` has the whole output, the same responses as spike 10's.

## A lane typed by its enum

`plod::Lane<U, M>` holds goose-http's `http::Lane` and the lane's mark, a variant of
the program's `Use`. `U` appears in no field: Goose takes a type parameter that only
names the type. `plod::ask(cx, lane: const Lane<U, M>&, job: U)` takes a variant of `U`
alone, so a report's job sent to the writer fails to compile (`wrong_lane.goose`):

```text
wrong_lane.goose:11: error: no matching overload for call to plod::ask
  candidate plod::ask at /…/goose-rest/waiting.goose:86: argument 3: cannot pass Reports.ReportTotals as U
    plod::ask(cx, cx.app.writer, Reports.ReportTotals { project: 1 });
```

The error names the job but not `Writes`, the enum `U` stands for there
([findings](../../docs/goose-findings.md#a-mismatch-names-the-type-variable-not-the-type-another-argument-bound-it-to)).

`plod::lane<U>(box) { u, a => run(u, w, a); }` instantiates its dispatch for one lane's
enum, so each lane's `run` cases cover that lane's variants with that lane's state:
`Writer` for the writer, `Reader` for the reports, `Hasher` for the hasher. A route that
waits on its own body or a pause, not a lane, needs no `run` on any lane. The three
lanes run three `thread_fn`s, as `docs/best-practices/lanes/` has them today.

Nothing tied that `U` to the lane the thread was opened for. The package typed the
thread's end too (2026-10-19): each thread takes a `jobs: plod::Jobs<Reports>`, which
`plod::lane_open<U>` checks, and calls `plod::lane(box, jobs)`, as `main.goose` now does
([decisions](../../docs/decisions.md#one-enum-of-jobs-per-lane)).

## The request state holds the lane's mark

Three ways for the state to hold the wait were tried:

- **The lane's mark, with the job carried back** (`main.goose`). `ask` stores the
  lane's mark, `Use.Write`, in `cx.state.use`, and sends the job. The lane's
  `plod::done(a, v)` replies the job's image, behind a two-byte length, and then `v`'s.
  `on_reply` dispatches `resume` on the mark, whose case reads the job back with
  `plod::job<Writes>(cx)` and dispatches again, to the domain's `resume`, which still
  gets the job's fields: `reports::resume` checks the reply against `u.project`.
- **An outer enum holding each lane's job** (`outer/main.goose`). A fixed-mode enum
  holds another as its payload (`Use { None, Write { job: Writes }, ... }`), and case
  functions dispatch on both levels: `resume(u: Use.Write)` calls `resume(u.job)`. But
  the package can't wrap a lane's job in the program's variant: each lane needs a
  `waiting(j: Writes) -> Use` of the program's, which a generic body in namespace `plod`
  finds by name in the global namespace, as a hook. The state grows to the largest job,
  as in spike 10.
- **A field per lane** (`sizes/main.goose`). Each lane's enum needs a `None` of its own,
  `ask` needs the same hook to pick the field, and the state is the sum of every lane's
  largest job.

No Goose form keeps a variant's tag without its payload: there is no tag accessor, and
no payload-less enum derived from another. The mark plus the job carried back is the
form that keeps the inputs out of the state.

The source cost: a route writes the same four pieces as spike 10's. A lane adds its
enum, its mark in `Use`, and its mark's `resume`, three lines in `app.goose`, and the
`lane_open` call names its enum and mark.

`sizes/main.goose`, in bytes (`expected.txt` there), measured as spike 10's:

| Request state | State | `plod::Slot` | goose-http's `RingConn` |
|---|---:|---:|---:|
| Tier M (`plod::NoState`) | 1 | 59 | 242 |
| Spike 10's `Use` | 131 | 189 | 372 |
| Spike 10's `Use` without the sign-in | 25 | 83 | 266 |
| The lane's mark | 1 | 59 | 242 |
| An outer enum holding the job | 132 | 190 | 373 |
| A field per lane | 165 | 223 | 406 |

The `Slot`s are 8 bytes larger than when the spike ran, for the promise in the
`http::Gather` that `plod::Exchange` holds from 2026-10-22.

The mark costs a connection nothing over tier M. The bytes move to the mail: each
reply carries its job back, 28 bytes for a `Writes` job, 12 for `Reports`, and 135 for
the sign-in's `Hashes` job, whose password thus crosses back to the worker, though the
worker doesn't keep it. A reply message is a slot of the worker's box, not memory per
connection, but a job and its answer must fit one slot (256 bytes by default) for
`answer` to read it. A lane's job on its box shrinks too: the writer's `Ask` image is
50 bytes and the reports' 34, where every job of spike 10's `Use` took 157.

`plod::reply` in pieces, read by `plod::relay`, needs the same prefix: the job comes
first, so the mark's `resume` can dispatch at the first piece, and `relay` would skip
the length and the job before sending the rest. The spike doesn't build that.

## The state is cleared once the route has answered

`on_reply` sets `cx.state.use` back to `Use`'s first variant, `None`, after the
`resume` when the route doesn't wait again, and before it fails the route for a job
that failed. A generic `cleared<T>(x: T&) { x = default<T>(); }` does it without
knowing `Use`, so `Use` must list `None` first. `main.goose` prints `then: Use.None`
after every response; the sign-in, which waits twice, keeps `Use.Write` between its
waits. With the mark, the job's inputs aren't in the state at all, so the reset only
keeps a stale mark from outliving its route. The package would clear it in
`on_reply`, as here; a wait that times out ends without a call to the handler, and
leaves the mark until goose-http resets the state for the next request.

The package dropped the reset (2026-10-19): it cleared an upload's variant before the
`CLOSED` that follows an early answer
([decisions](../../docs/decisions.md#one-enum-of-jobs-per-lane)). `main.goose` now
prints the last mark the route set, as `expected.txt` has it.

## A catch-all run: caught when it doesn't reply

With an enum per lane a lane needs no catch-all: its dispatch covers its own variants
only. A catch-all still hides the cases, untyped (`fn run(u, w: Writer&, a)`) or typed
with the lane's enum (`fn run(u: Writes, ...)`), both exact matches that win before
dispatch (`catch_all/main.goose`). Goose has no reflection, and no way to require
that a call dispatch, so the package can't refuse one at compile time
([findings](../../docs/goose-findings.md#an-overload-that-takes-the-whole-enum-hides-its-case-functions-without-a-word)).

The lane's loop catches the usual case at run time. It passes `run` the job as a
`Took<U>` by reference, `F(a.job, &a)`, and `done` sets its `replied`. A `run` that
returns without replying or failing gets 500 `no_reply` for the route, in place of a
504 once the wait's time runs out:

```text
untyped catch-all:
  no_reply: the lane answers 500 for Create { 3 }
  no_reply: the lane answers 500 for Close { 9 }
  rows written: 0
```

On the real lanes, `main.goose`'s jobs all reply, and none gets `no_reply`. A
catch-all that replies is still silent, so the docs should warn against one too.

## Pieces and files

| | Spike 10 | Spike 11 |
|---|---|---|
| Per waiting route | 4 in 2 files: a variant of `Use`; the route, `run`, `resume` | 4 in 2 files: a variant of its lane's enum; the route, `run`, `resume` |
| Per lane | an `App` field and its `lane_open` | the same, and its enum, its mark in `Use`, its mark's `resume`, and its own `thread_fn` and state |
| Once per program | `Use`, `St`, one `Db`, one `thread_fn`, `run` and `resume` for `Use.None` | `Use` of marks, `St`, `resume` for `Use.None` |

Spike 11 trades three lines per lane, all in `app.goose`, for a compile-time check of
each job's lane, a state type per lane, a one-byte request state, and no `run` for
another lane's jobs. A program has a few lanes and many routes, so the per-route count
matters more, and it is unchanged.
