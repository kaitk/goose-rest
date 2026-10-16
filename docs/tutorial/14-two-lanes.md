# 14. Two lanes, or a reply in pieces

One job per route covers a use case that one lane can handle alone. Two cases need
more: a reply too large for one message, and a route that waits on one lane and then
another. Both use the same `Waiting` enum and case functions as
[the previous page](13-waiting.md).

## A reply in pieces

A project's tasks, as JSON, can be longer than a message. The lane replies with
`rest::reply`, which sends a reply longer than the worker's message size in pieces. From
[`14-two-lanes`](14-two-lanes/main.goose), whose worker takes messages of 64
bytes, so that a project's tasks arrive in several pieces:

```rust
            if tag == TASKS {
                let a, ok = rest::asked<TasksJob>(bytes);
                // In pieces of the worker's message size, 64 bytes here.
                if ok { rest::reply(a, tasks_json(c, a.job)); }
```

The route's case function runs for each piece. `rest::relay` starts a chunked response
with the first piece and sends each subsequent piece as a chunk, waiting again until
the final piece arrives:

```rust
// Called for each piece of the reply: rest::relay sends the first, and the
// ones after it, as a chunked response.
fn resume(w: Waiting.Tasks, cx) { rest::relay(cx, 200, "application/json"); }
```

```text
GET /v1/projects/2/tasks 200 [{"id":6,"title":"Name it","assignee":2}]
```

The worker holds one piece at a time, however long the reply. The lane writes the
whole reply first, so it holds all of it. Data too large for that is made a piece at a
time as the client takes it ([long responses](12-long-responses.md)).

## Two lanes in turn

Inviting a user to a project adds a member to the database, then sends an email through
a separate mailer lane. Neither lane can do both, so the route waits on one and
then the other, using a `Waiting` variant for each step:

```rust
enum Waiting {
    None,
    Tasks,
    Member { project: i64, user: i64 },
    Mail { project: i64, user: i64 },
}
```

The first case function asks the second lane, and waits again:

```rust
// The database added the member: ask the mailer next, and wait again.
fn resume(w: Waiting.Member, cx) {
    let r, ok = rest::read_reply<MemberReply>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    guard r.status < 400 else { rest::fail(cx, r.status, r.code); }
    rest::ask(cx, cx.app.mailer, SEND, MailJob { project: w.project, user: w.user },
              Waiting.Mail { project: w.project, user: w.user });
}

fn resume(w: Waiting.Mail, cx) {
    let r, ok = rest::read_reply<MailReply>(cx);
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
| One lane, a reply that fits a message | One job, one case function ([Work that waits](13-waiting.md)) |
| One lane, a longer reply | One job, `rest::reply` in pieces, and `rest::relay` |
| Two lanes in turn | A `Waiting` variant per wait; the first case function requests work from the next lane |

Each wait has its own time limit, and each request can encounter a full box, so a
route that waits twice can fail at either step. A 503 at the second step comes after the
first lane has finished its work. If the second step can happen later, such as
sending an email, the lane can forward the work itself and the route waits only once.

---

[Index](README.md) · Previous: [13. Work that waits](13-waiting.md) · Next:
[15. Limits](15-limits.md)
