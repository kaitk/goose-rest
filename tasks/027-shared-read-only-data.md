# 027: A helper for read-only data every worker shares

Status: deferred (asked for 2026-10-15; deferred 2026-10-15 until a program needs it)

## Decided (2026-10-15): no goose-rest helper yet

Read-only data falls into three cases, and only one needs the store:

1. **Known at build time** (holidays, translations, lookup tables shipped with a
   release): `const` globals with compile-time initializers, which Goose shares between
   workers as static data with no copy (spec §11.2). Task 037 checks that large literal
   arrays compile well.
2. **Fixed at runtime, too large to copy per worker** (a GeoIP database, a catalog or
   code list loaded at boot, an index built at startup): goose-http's `http::store`,
   which a goose-rest program already imports directly (`import http.store`), as the
   benchmark server does and tutorial page 8 says. Its reads get cheaper with goose-http's
   task 040, typed reads by value.
3. **Changing while running**: per worker, or an owner thread the routes ask (tutorial
   pages 8 and 13), as now. goose-http's mailboxes stay as they are, not extracted into a
   package of their own yet.

snowtime, the model application, has nothing in case 2: its reference data is known at
build time, its small settings are copied per worker at no cost, and the rest is in its
database. So the helper below waits until a real program shows what its API should be.
The planned design further down stays as the record of that thinking, with its
alternatives: JSON per record, record images, columns, and an owner thread.

Data a program loads in `main`, such as records or prebuilt JSON, is copied into every
worker by `thread_spawn`, so it costs its size once per worker. Task 020 found this to
be most of goose-rest's extra memory on tiers A to C: the tier server keeps 4.5 to 71 MiB
per worker that goose-http's keeps once. goose-http's shared store, `import http.store`,
keeps one copy that every worker reads, but a goose-rest program has to wire it up
itself, and nothing in goose-rest's docs points a reader to it.

## How the records are laid out (2026-10-15)

Records in memory pay for how their strings are stored. A generated type's string with
`maxLength` is a limited array, which takes its full capacity, 4 bytes per code point
(task 033 cuts it to 1 for ASCII). One without it is a `u8[]`, exact, but it makes the
record variable-size: such records can't be elements of an array that's indexed or
shrunk, only of a sequential `T[]` or `T[>..]`, and can't be changed after they're built
(spec §3.3, §3.4, §4.4). The options, in the order to try them:

1. **Prebuilt JSON in `http::store`**, as the benchmark's template mode keeps it: the
   most compact, for data sent as it is rather than queried by field.
2. **A sequential array of exact records, with an index**: spec §3.3's own answer for
   random access to variable-size elements, a second array of references, 4 bytes
   each (`T&<u32 in pool>`). Lookup is O(1) and every string exact; a record can be
   replaced only by pushing another. That suits data built at startup and only read.
3. **A stored companion type**: for each schema type the generator would also write
   one with strings as ranges into one byte pool (`Str`), as the benchmark server keeps
   its records, with a function from the one to the other. Fixed-size, so records can
   be indexed and replaced; the most generator work. Only if programs need to change
   cached records in place.

## Acceptance criteria

- [ ] A goose-rest helper loads read-only data once and gives each worker's `cx.app` a
      view of the shared copy, built on `http::store`, with a program that uses it and
      a test that the data isn't copied per worker
- [ ] The tutorial's page 8, "Per worker", and page 1, "Workers and `main`", say what
      copying into every worker costs, and point to the helper
- [ ] The reference documents it, with what may and may not go in it (read-only, built
      before the workers start)

## Planned design (2026-10-15)

Proposed, not built: waiting for approval. The helper keeps a table of records' JSON in
goose-http's shared store, one copy per process, and each worker holds three integers
that name it. It supports layout 1, prebuilt JSON, with an index, also in the store.

### The API

A module of its own, `rest.shared` (`shared.goose`), which `rest` doesn't import, as
`rest.compression` isn't: a program without it doesn't build goose-http's store shim.

| Call or type | Thread | Does |
|---|---|---|
| `struct Table { json: u8[>..], ends: u32[>..] }` | loader | The records being built: their JSON end to end, and where each ends |
| `fn add(t: Table&, v)` | loader | Appends `v`'s JSON, written by its `format` overload as `rest::json` writes it, and ends a record |
| `fn add_json(t: Table&, json: const u8[:])` | loader | Appends a record's JSON the program wrote itself |
| `fn share(t: Table&) -> Shared` | loader | Puts the JSON and the index in the store, and empties `t` |
| `fn freeze_shared()` | loader | Ends the writes: a `share` after it aborts. Once, after the last `share` |
| `struct Shared { data: http::Blob, index: http::Blob, count: i64 }` | any | The shared table. Flat, so it crosses `thread_spawn` and queues; `count` is the number of records |
| `fn shared_json(cx, status: i32, s: Shared, i: i64)` | worker | Answers record `i` as `application/json`, copied from the store straight into the response; 404 `not_found` for an `i` outside `0..count` |
| `fn append_shared(s: Shared, i: i64, out: u8[>..]&) -> bool` | worker | Appends record `i`'s JSON to `out`, for a list or a record inside a larger answer; false for an `i` outside |

The program:

```rust
import http from "github.com/kaitk/goose-http@v0.5.6";
import rest from "github.com/kaitk/goose-rest@<tag>";
import rest.shared;

struct Item { id: i64, name: u8[], price: i64 }

fn format(out: u8[>..]&, v: const Item&) { ... }   // or a generated type's

struct App { items: rest::Shared }

// Builds the table on a thread of its own, whose data stack the runtime
// unmaps when it returns, and hands main the table's ids.
thread_fn load(dir: u8[..256]) {
    var t = rest::Table { .. };
    each_item(dir) { item => rest::add(t, item); };
    qput(rest::share(t));
    rest::freeze_shared();
}

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/items/:id") {
            rest::route(cx) { rest::shared_json(cx, 200, cx.app.items, rest::param_int(cx, "id") - 1); };
        } else {
            rest::otherwise(cx);
        }
    };
}

thread_fn worker(cfg: http::Config, items: rest::Shared) {
    var app = App { items: items };
    let e = rest::serve(cfg, app) { cx => handle(cx) };
    if e.code != 0 { http::report(e); }
}

fn main() {
    ...
    thread_wait(thread_spawn(load, dir));
    let items = qget<rest::Shared>();
    for i in http::worker_count(cfg) { ids.push(thread_spawn(worker, cfg, items)); }
    for id in ids { thread_wait(id); }
}
```

### Data flow

```text
load (thread)          store (C, once)              each worker
  read, build records    data:  {..}{..}{..}          App { items: Shared }  24 bytes
  add -> Table           index: 0, e0, e1, ... (u32)    shared_json(cx, 200, items, i):
  share(t) ---------->   put both, t emptied              2 store reads -> cx.out.buf
  freeze_shared()
  qput(Shared) --> main: qget, thread_spawn(worker, cfg, items) --> each worker
  returns: its data stack is unmapped
```

- A loader thread the program writes builds the records and calls `add`, `share`, and
  `freeze_shared`, then returns. `main` waits for it before it spawns a worker. Built in
  `main` instead, the data works the same, but `main`'s data stack keeps its high-water
  mark for the program's life, so `main` holds the files and the table it read once
  more (task 020, fix 1).
- `share` puts the JSON and the index in the store as two blobs. The `Shared` value
  reaches `main` on a queue, and each worker as a `thread_spawn` argument; both order
  the store's writes before the workers' reads, as the store's contract requires. The
  worker puts it in its `App`, and a route reads it as `cx.app.items`.
- After startup, the store holds the JSON and 4 bytes per record plus 4, once per
  process, in C's heap. Each worker holds the 24-byte `Shared`. `main` holds the same
  24 bytes, and the loader nothing.

### Layout

It supports layout 1, prebuilt JSON, first, because it's the only one the store holds
without a goose-http change. The store keeps bytes, and a read copies a range into a
Goose array (spec §7.10: C can't hand Goose a view of its memory). Goose values aren't
shared between threads (§11.2), so layout 2's array of records and its `T&<u32 in
pool>` index stay per worker wherever they're built: each worker would hold a copy, the
cost this task removes. It also serves the common case, records sent as they are, with
one copy per request, the same as `rest::json_bytes` from a worker's own buffer.

- A record is found by its index, `0` to `count - 1`, in the order the loader added it.
  A program whose ids are dense maps an id to an index itself (`id - 1` above); one with
  sparse or string keys keeps a key array per worker, or adds records sorted by key and
  searches (open question 1).
- A record is its JSON bytes, exact, whatever its strings' types were. The index is
  `count + 1` offsets, `u32`, so a table holds at most 4 GiB of JSON; `share` aborts
  past it. A read takes offsets `i` and `i + 1` in one 8-byte store read, then the
  record's range.
- A route that needs a record's fields, to filter or to change an answer, appends it to
  a buffer of the request's and parses it with the type's reader (`api::read_item` for a
  generated type). That costs a parse per read; a field read on every request belongs
  in a small per-worker array instead.

### What may and may not go in it

- Records built before the workers start, by `share` before `freeze_shared`, and only
  read after. Nothing in the API writes to a shared table: `Shared` holds ids, and a
  worker reads through `shared_json` and `append_shared`.
- A `share` after `freeze_shared`, to build or extend a table while the workers run,
  aborts with a message naming the call: the store refuses a put after its freeze
  (`EPERM`). A program that calls `share` from a worker before any freeze, against the
  docs, races with the other workers' reads, which nothing detects.
- Data that changes, such as counters, sessions, or records a request creates, stays
  per worker or on an owner thread (tutorial page 8), as it does now. To change a shared
  table, restart the program.

### The generator

A generated schema type goes in as it is: `rest::add(t, v)` writes it with its generated
`format` overload. Its limited arrays don't matter, since the store keeps the JSON at
its exact length, so a `maxLength: 200` string costs its own bytes, not 800. Task 033's
`format: ascii` changes nothing in the store. It shrinks only the one record the loader
builds at a time, and a record a route parses back from its JSON.

### Cost

- At startup: each record written as JSON once, and copied once into the store; the
  loader's peak is the files it read plus the table.
- Per read: two calls into the store, an 8-byte copy into a local buffer, and the
  record's bytes copied once into the response.
- Per worker: 24 bytes, instead of the table's size.
- To measure:
  - Idle RSS with 1, 2, and 4 workers, as task 020's "How this was measured" does, of
    the example program serving a table of about 40 MB (200,000 synthetic items), and
    of the same program keeping the JSON in a global that `thread_spawn` copies,
    which isn't committed. A worker's cost is half the difference between 4 and 2
    workers. Expected: about 0.5 MiB per worker shared, against twice the table copied.
  - A check in `scripts/test-examples.sh` that the example's RSS with 4 workers is
    less than with 1 plus half the table, where `ps` reports RSS (open question 3).
  - Requests per second on `GET /items/:id`, shared against the copied table, wrk with
    the machine, command, and rounds recorded, to show what the two store calls cost.
- The program: a new example, `examples/catalog/`, with a `requests.sh` and
  `expected.txt` for `scripts/test-examples.sh`. Page 8's program shows per-request
  state with one worker, and shared data needs several to show (open question 4).

### Alternatives not taken

- Layout 2, a sequential array of exact records with an index: a Goose array can't be
  in the store or shared between threads, so each worker would hold a copy. In the
  store as bytes, each read would decode a record, and each type would need a binary
  encoding and its decoder, written by the generator, for no gain over JSON when the
  record is sent as it is.
- Layout 3, a stored companion type: the same barrier, the most generator work, and it
  serves records changed in place, which a read-only table rules out.
- The index per worker, an `i64[>..]` in `App`: 8 bytes per record per worker, and
  twice that at spawn. In the store it's 4 bytes once, for one more store read per
  request.
- `share` freezing the store itself: a program could then share one table only.
- `share` returning an error code, as `http::store_put` does: its failures (out of
  memory, after the freeze, past 4 GiB) are startup bugs, and an abort with the cause
  keeps every caller's code shorter (open question 2).
- A helper that spawns the loader itself: a `thread_fn` takes no block, so it can't run
  the program's code, and the program writes the loader thread.
- Static data: only a `const` global with a compile-time initializer is shared
  (§11.2), and data loaded at startup has none.

### Open questions

1. Lookup by index only, or also by an integer key: records added in key order, with a
   sorted key array in the store and a binary search, one store read per step?
2. Should `share` abort on failure, or return an error code as `http::store_put` does?
3. Should the RSS check run in `scripts/test.sh`, or is a measurement recorded here
   enough? RSS differs by platform, so the check would allow a wide margin.
4. A new `examples/catalog/`, or the shared table added to page 8's program, which then
   runs several workers?
5. The names: `rest.shared`, `Table`, `add`, `share`, `freeze_shared`, `Shared`,
   `shared_json`, and `append_shared`.
