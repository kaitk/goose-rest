# 017: A service learns that the client it works for has gone

Status: todo (asked for 2026-10-14)

Found in task 015's review (2026-10-14), at goose-http `bc75f2a`. A route that asked
another thread (`rest::ask`) and whose client then closes the connection, or whose wait
times out, gets nothing more: goose-http's loop finds no exchange waiting for the reply's
key, whose connection generation has moved on, and drops the reply (`epoll.goose`'s
`delivered`). The worker does no work for a client that has gone. The service doesn't
know: `http::mail_send` to that key returns `SENT`, so the service does the whole job,
and for a reply in pieces sends every piece. Tina's design, which goose-http's mailbox
follows, has a send say at once that an address is stale; here a send says so only when
the whole box is closed or opened again.

`waiting.goose`'s doc of `rest::answer` claims more than it does: "Returns false when the
route has gone, as when its connection closed". It returns false only for a closed box,
a stopped worker, or a piece longer than a slot.

## The change

**Now, in goose-rest alone:** correct `rest::answer`'s doc:

```goose
// ... Returns false when the worker's box has closed, as when it stopped, or
// when a piece is longer than the box's slots. A reply to a route whose
// client has gone, or whose wait has timed out, is sent and dropped by the
// worker: the service can't tell yet (task 017).
```

**Then, with goose-http:** a send to the key of an exchange that no longer waits
returns `STALE`. One way, for goose-http's task 027 to decide (proposed there only after
asking the maintainer): a box opened with a table of live keys, indexed by a key's high
bits, which only its owner sets and clears, and which `mail_send` reads atomically
before it takes a slot. goose-http's loop sets a connection's entry when its exchange
waits (`http::later`) and clears it when the exchange is woken, times out, or its
connection closes. A key whose entry doesn't match gets `STALE`. A cheap
`http::mail_live(to)` reads the same entry without sending.

goose-rest then changes little, since `rest::answer` already stops on `STALE`:

```goose
// Whether the route that asked a still waits for its reply: false once its
// client has gone, its wait has timed out, or the worker has stopped. A
// service checks it before work worth skipping.
fn wanted(a) -> bool { http::mail_live(a.reply) }
```

and a service skips the job, or stops its pieces, for a client that has gone:

```goose
if tag == EXPORT {
    let a, ok = rest::asked<ExportJob>(bytes);
    guard ok && rest::wanted(a) else { return; }   // the client has gone: no query
    let text = export(a.job);
    rest::answer(a, text);                          // false: it went while we worked
}
```

`rest::answer`'s retry on `FULL` then ends too, where today it retries every millisecond
for as long as the worker's box stays full, for a client that may be gone.

## Acceptance criteria

- [ ] `rest::answer`'s doc says what it returns false for
- [ ] goose-http's task 027 has the request, after asking the maintainer, and its
      answer is recorded here
- [ ] With it: a test where the client closes before the service answers, and the
      service's send returns `STALE`; `rest::wanted`, and `examples/waiting`'s database
      thread skipping a job and stopping an export's pieces for a client that has gone
- [ ] The tutorial's limits section (task 016) shows it
