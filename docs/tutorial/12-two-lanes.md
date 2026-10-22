# 12. Two lanes, or a reply in pieces

One job per route covers a use case that one lane can do alone. Two cases need
more: a reply too large for one message, and a route that waits on one lane and then
another. Both use the same jobs, `run`, and `resume` case functions as
[the previous page](11-waiting.md).

## A reply in pieces

A project's tasks, as JSON, can be longer than a message. The lane replies with
`plod::reply`, which sends a reply longer than the worker's message size in pieces,
the job in front of the first. From [`12-two-lanes`](12-two-lanes/main.goose), whose
worker takes messages of 64 bytes, so that a project's tasks arrive in several pieces:

```rust
// On the database lane: the project's tasks as a JSON array, in pieces of
// the worker's message size, 64 bytes here.
fn run(u: DbJob.Tasks, c: db::Conn&, a) {
```

```rust
    plod::reply(a, out);
}
```

The route's case function runs at the first piece. `plod::relay` starts a chunked
response with what follows the job in it, and Plod sends each later piece as a
chunk, waiting again until the last one arrives:

```rust
// Called at the first piece, which starts a chunked response; the rest go on as chunks.
fn resume(u: DbJob.Tasks, cx) { plod::relay(cx, 200, "application/json"); }
```

```text
GET /v1/projects/2/tasks 200 [{"id":6,"title":"Name it","assignee":2}]
```

The worker holds one piece at a time, however long the reply. The lane writes the
whole reply first, so it holds all of it. Data too large to hold in full is written
one piece at a time as the client reads it ([long responses](15-long-responses.md)).

## Two lanes in turn

Inviting a user to a project adds a member to the database, then sends an email through
the mailer, a lane of its own. Neither lane can do both, so the route waits on one and
then the other. Each lane has its enum of jobs, and `Use` a mark for each:

```rust
// Each lane's jobs.
enum DbJob {
    Tasks { project: i64 },
    AddMember { project: i64, user: i64 },
}
enum MailJob { Invite { project: i64, user: i64 } }

// What a route waits on: one lane or the other.
enum Use { None, Db, Mail }
```

`main` opens each lane as the previous page's, and hands both to the worker in `App`:

```rust
    let app = App {
        db: plod::lane_open<DbJob>(http::LaneConfig { .. }, Use.Db, database),
        mailer: plod::lane_open<MailJob>(http::LaneConfig { .. }, Use.Mail, mailer),
    };
```

<details>
<summary>The routes, which ask the database first, and the marks' resumes</summary>

From [`main.goose`](12-two-lanes/main.goose):

```rust
        plod::get(cx, "/v1/projects/:id/tasks") {
            plod::ask(cx, cx.app.db, DbJob.Tasks { project: plod::param_int(cx, "id") });
        };
        plod::post(cx, "/v1/projects/:id/members") {
            let user, has_user = plod::query_int(cx, "user");
            plod::require(cx, "user", has_user);
            plod::ask(cx, cx.app.db, DbJob.AddMember { project: plod::param_int(cx, "id"), user: user });
        };
```

```rust
fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Db, cx) { resume(plod::job<DbJob>(cx), cx); }
fn resume(u: Use.Mail, cx) { resume(plod::job<MailJob>(cx), cx); }
```

</details>

The database's `run` refuses a member already added, or a project that doesn't
exist, with `plod::fail`, and replies the job alone otherwise. Its `resume` asks the
second lane, and waits again; the job came back with the reply, so it holds the
project and the user:

```rust
// The database added the member: ask the mailer next, and wait again. The
// job came back with the reply, so its project and user are at hand.
fn resume(u: DbJob.AddMember, cx) {
    plod::ask(cx, cx.app.mailer, MailJob.Invite { project: u.project, user: u.user });
}
```

```rust
fn resume(u: MailJob.Invite, cx) {
    plod::json(cx, 201, Invited { project: u.project, user: u.user, mail: plod::answer<i64>(cx) });
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
| One lane, a reply that fits a message | One job, `plod::reply_value`, and `plod::answer` ([Work that waits](11-waiting.md)) |
| One lane, a longer reply | One job, `plod::reply` in pieces, and `plod::relay` |
| Two lanes in turn | A job on each lane; the first job's `resume` asks the next lane |

Each wait has its own time limit, and each ask can meet a full box, so a
route that waits twice can fail at either step. A 503 at the second step comes after the
first lane has finished its work. If the second step can happen later, such as
sending an email, the lane can forward the work itself and the route waits only once.

*Note: the best practices keep a route to one slow step where it can, and name the
route beside each of its jobs in the lanes' enums, in the order they run
([A route with two slow steps](../best-practices/lanes.md#652-a-route-with-two-slow-steps)).*

---

[Index](README.md) · Previous: [11. Work that waits](11-waiting.md) · Next:
[13. Limits](13-limits.md)
