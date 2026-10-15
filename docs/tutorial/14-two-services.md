# 14. Two services, or a reply in pieces

One job per route covers a use case one service can do alone. Two cases need more: a
reply too long for one message, and a route that waits on one service, then on another.
Both use the same `Waiting` enum and case functions as [the previous page](13-waiting.md).

## A reply in pieces

A project's tasks, as JSON, can be longer than a message. The service answers them with
`rest::answer`, which sends a reply longer than the worker's messages in pieces. From
[`14-two-services`](14-two-services/main.goose), whose worker takes messages of 64
bytes, so that a project's tasks come in several:

```rust
            if tag == TASKS {
                let a, ok = rest::asked<TasksJob>(bytes);
                // In pieces of the worker's message size, 64 bytes here.
                if ok { rest::answer(a, tasks_json(c, a.job)); }
```

The route's case function is called for each piece. `rest::relay` sends the first as
the start of a chunked response, and each one after it as a chunk, waiting again until
the last:

```rust
// Called for each piece of the reply: rest::relay sends the first, and the
// ones after it, as a chunked response.
fn resume(w: Waiting.Tasks, cx) { rest::relay(cx, 200, "application/json"); }
```

```text
GET /v1/projects/2/tasks 200 [{"id":6,"title":"Name it","assignee":2}]
```

The worker holds one piece at a time, however long the reply. The service writes the
whole reply first, so it holds all of it. Data too large for that is made a piece at a
time as the client takes it ([long responses](12-long-responses.md)).

## Two services in turn

Inviting a user to a project adds a member in the database, then sends an email through
a mailer, a service of its own. Neither can do both: the route waits on one, then on
the other, a state with a `Waiting` variant each:

```rust
enum Waiting {
    None,
    Tasks,
    Member { project: i64, user: i64 },
    Mail { project: i64, user: i64 },
}
```

The first case function asks the second service, and waits again:

```rust
// The database added the member: ask the mailer next, and wait again.
fn resume(w: Waiting.Member, cx) {
    let r, ok = rest::reply_value<MemberReply>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    guard r.status < 400 else { rest::fail(cx, r.status, r.code); }
    rest::ask(cx, cx.app.mailer, SEND, MailJob { project: w.project, user: w.user },
              Waiting.Mail { project: w.project, user: w.user });
}

fn resume(w: Waiting.Mail, cx) {
    let r, ok = rest::reply_value<MailReply>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    rest::json(cx, 201, Invited { project: w.project, user: w.user, mail: r.id });
}
```

```text
POST /v1/projects/1/members?user=3 201 {"project":1,"user":3,"mail":1}
POST /v1/projects/1/members?user=3 409 {"error":"already_a_member"}
POST /v1/projects/9/members?user=3 404 {"error":"project_not_found"}
```

## When to pick which

| The route needs | Shape |
|---|---|
| One service, a reply that fits a message | One job, one case function ([Work that waits](13-waiting.md)) |
| One service, a longer reply | One job, `rest::answer` in pieces, and `rest::relay` |
| Two services in turn | A `Waiting` variant per wait, each case function asking the next |

Each wait has its own time limit, and each can find a box full, so a route that waits
twice can fail at either: the second wait's 503 comes after the first service's work is
done. Where the second step can come later, such as an email, a service can send it on
by itself, and the route waits once.

---

[Index](README.md) · Previous: [13. Work that waits](13-waiting.md) · Next:
[15. Limits](15-limits.md)
