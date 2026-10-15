# 016: A step-by-step tutorial, up to services for routes that wait

Status: done (2026-10-15), pages 11 and 12 included, built with task 023

`docs/tutorial.md` shows goose-rest a feature at a time. A program that does more than
the simple cases needs to see the approaches this package takes, in the order it meets
them, each section building on the last, as Actix's and Elysia's guides do. Task 015's
review against two real APIs (one on SQLite, one on Postgres) found the approach a tutorial most needs and doesn't show yet: how a route that
waits on a database stays simple.

This task writes that tutorial. How it's set up (one document or several, its programs,
how `scripts/test.sh` checks them) is decided when the work starts. It waits on task
015's merge, so that it teaches A to F's API.

## The approaches, from simple to complex

1. Routes, scopes, and extractors in a `rest::routes` block.
2. Answers and errors: `rest::fail` from any depth below `rest::route`.
3. JSON bodies, read by hand and through `rest::take`.
4. The whole API from a schema, and hand-written routes beside `dispatch`.
5. Middleware and scopes: the package's and a program's own.
6. State: the worker's in `cx.app`, the request's in `cx.state`, and `rest::once`.
7. Large bodies, and the code before `rest::body` that runs twice.
8. Testing without sockets, `rest::serve_one`.
9. Work that's synchronous and quick, such as an embedded SQLite, in the handler.
10. Work that waits, through a service (below): one job per route.
11. Waiting on two services, or streaming a reply: the case functions over a `Waiting`
    enum, for what a service can't do alone.
12. Limits and backpressure: `http::Config`'s bounds, 503 when a service's box is full,
    504 when it doesn't answer in time, a slow client, and a client that has gone
    (task 017).

## The pages (2026-10-15)

Agreed with goose-http's task 035, which records why. The tutorial is pages under
`docs/tutorial/`, each `NN-name.md` with its program in `NN-name/`, indexed by
`docs/tutorial/README.md`; `docs/tutorial.md` goes. Each page links the goose-http
section it builds on, in a sentence.

| Page | Approach | goose-http's `docs/patterns.md` |
|---|---|---|
| **Part one: the basics** | | |
| 1. Running something | The one idea, and 1 | (its README's "Concepts") |
| 2. Routes, path, query, and headers | 1 | |
| 3. Answers and errors | 2 | |
| 4. JSON bodies | 3 | "Request bodies" |
| 5. The API from a schema | 4 | |
| 6. The schema in TypeScript, Python, or Rust | 4 | |
| 7. Middleware and scopes | 5 | |
| 8. State | 6 | "State that workers share" |
| 9. Testing without sockets | 8 | |
| **Part two: bodies, waits, and limits** | | |
| 10. Large bodies | 7 | "Request bodies" |
| 11. Bodies read as they arrive | TBD: goose-rest reads no body in pieces yet | "Request bodies" |
| 12. Long responses and files | TBD: goose-rest sends no response in pieces yet | "Long responses" |
| 13. Work that waits | 9, then 10 | "Mail between threads", "Slow work" |
| 14. Two services, or a reply in pieces | 11 | "Mail between threads" |
| 15. Limits | 12, and minutes-long work as a job the client polls | "Limits" |
| 16. Embedded Linux | | (its `docs/embedded.md`) |

The fake database is the tutorial's own code, rows in memory with a set delay per
query, called as plain functions: `db::fetch_all<Project>(conn, sql, owner)`. Goose
v2026.1 can't chain calls on another namespace's functions, nor pass a type argument
to a call written `x.f()` (task 035).

## The service pattern

Preferred (2026-10-14) for any route that waits on another thread, such as a database's,
over a state machine that waits once per query.

Goose has no `async` and can't keep a function to call later, so a route that waits
returns, and resumes in a case function when the reply comes (architecture doc,
"Waiting on another thread"). A route that waits once per query is a state machine of as
many `Waiting` variants as it has queries, each resume a function of its own: a use case
of three queries reads as three fragments. Instead, the route sends one job that names
the whole use case, and a service thread does it start to end, synchronously, as an
Axum or Elysia handler's body would:

- **The route** reads and checks the request (extractors, the generated readers),
  authenticates where it can in place, such as a JWT, and asks once:
  `rest::ask(cx, cx.app.db, BOOK, BookJob { .. }, Waiting.Book { .. })`.
- **The service**, a thread or a pool of them that owns the database connections, takes
  each job with `rest::asked<J>`, runs its queries in one transaction, and answers once
  with `rest::answer_value`, or `rest::answer` with JSON it wrote.
- **The resume** turns the reply into the answer: `rest::relay` for JSON the service
  wrote, or `rest::reply_value` and `rest::json`. A reply that carries an error's status
  and code calls `rest::fail`, so every error keeps one shape.

A sketch, against task 015's API, not yet compiled:

```goose
struct BookJob { patient: i64, slot: i64 }
struct BookReply { status: i32 = 201, code: u8[..32] = "", id: i64 = 0 }

fn book(cx, user: const u8[:], body: const api::Booking&) {
    rest::ask(cx, cx.app.db, BOOK, BookJob { patient: body.patient, slot: body.slot }, Waiting.Book);
}

fn resume(w: Waiting.Book, cx) {
    let r, ok = rest::reply_value<BookReply>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    guard r.status < 400 else { rest::fail(cx, r.status, r.code); }
    rest::json(cx, 201, Booked { id: r.id });
}

// On the service's thread: plain synchronous code, testable without HTTP.
fn book_slot(db: Db&, j: BookJob) -> BookReply {
    db.begin();
    guard db.slot_free(j.slot) else { db.rollback(); return BookReply { status: 409, code: "slot_taken" }; }
    let id = db.insert_booking(j.patient, j.slot);
    db.commit();
    return BookReply { id: id };
}
```

Why it's preferred:

- A use case reads as one function, next to its data, and its queries share one
  transaction; a state machine can't hold a transaction across its waits without tying
  a connection to a request.
- Each route waits once: one `Waiting` variant per route, one time limit, and one place
  a full box sheds load (503), as Tina's mailboxes do.
- A service function is tested as a plain call on a job, without a request.
- It's how goose-http's mailbox was meant to be used: work sent to an address, bounded,
  with a time limit on every wait.

What it costs: a job and its reply cross as flat values, in slots of `Config.mail_size`
bytes, or in pieces past it; the HTTP layer and the use cases live in different
functions; and a program with several services picks an address per job, such as one
per worker. A check that needs the database before the route, such as a session looked
up by its cookie, goes in the job, so that the route still waits once.

The state machine stays for what one service can't do: a route that waits on two
services in turn, or a reply streamed in pieces (the tutorial's page 14).

## Acceptance criteria

- [x] The pages and the goose-http sections each links to are agreed (2026-10-15)
- [x] The tutorial covers the twelve approaches above in that order, each with a program
      `scripts/test.sh` builds and requests; a body of any size read in pieces, under
      approach 7, waits on task 023
- [x] The service pattern is shown on a route of several queries in one transaction, with
      a service function tested without HTTP, and an error from the service in the
      error shape (page 13)
- [x] The state machine is shown where it's needed, and the tutorial says when to pick it
      (page 14)
- [x] Limits and backpressure are shown answering: 503 for a full box, 504 for a late
      reply, and a client that has gone (task 017; page 15)
- [x] The architecture doc's "Waiting on another thread" names the service pattern as
      the default
