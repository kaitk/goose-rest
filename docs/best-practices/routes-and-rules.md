# 3. Routes and rules

The first code that becomes hard to change in a web application is often the handler that
does everything: it reads the request, decides what the domain allows, writes to the
database, and builds the answer. Its decisions can then be tested only through HTTP,
and a change to the request's shape sits in the same function as a change to the
domain's logic. Most frameworks' guides warn against this "fat controller". goose-rest's
applications split the work three ways:

- The **route** handles HTTP: it reads the request, checks its shape, and answers.
- The **rule** makes decisions: it takes typed values and returns a result or the reason
  the domain refuses the operation.
- The **job** does slow work, such as database operations, on a lane and calls the
  rules ([Lanes and jobs](lanes.md)).

A domain's routes and jobs are in its `routes.goose`, and its rules in `rules.goose`
([Layout by domain](layout.md#22-the-same-files-in-every-domain)).

This page follows one request, `POST /projects` with a name, through its route and its
rule. The code is from [`routes-and-rules/`](routes-and-rules/), which keeps projects in
the worker's memory rather than a database. With a database, the route would ask for a
job that calls the same rule.

## 3.1 What a route does

A route reads what it needs from the request, calls a rule or asks for a job, and
answers with the result or error. From
[`routes-and-rules/projects/routes.goose`](routes-and-rules/projects/routes.goose):

```rust
fn create(cx) {
    let name, has = rest::form(cx, "name");
    // 400 invalid_parameter for a request without a name: the rule never runs.
    rest::require(cx, "name", has);
    let project, err = new_project(CreateInput { name: name }, cx.app.projects.len + 1);
    // The rule's refusal, such as 422 project_name_required, ends the route.
    check(err, cx);
    // In place of a job on a lane, as the program has no database.
    cx.app.projects.push(project);
    rest::json(cx, 201, project);
}
```

Everything here is about HTTP; the decision is the rule's, and `check` turns its
refusal into a status and code ([Errors](errors.md#42-each-domains-codes-in-one-place)). A
route kept to this shape fits on one screen, and reads the same in every domain.

<details>
<summary>The projects' other route, <code>archive</code>, and their entry</summary>

From [`routes-and-rules/projects/routes.goose`](routes-and-rules/projects/routes.goose):

```rust
fn routes(cx) {
    rest::post(cx, "") { create(cx); };
    rest::post(cx, "/:id/archive") { archive(cx); };
}
```

```rust
fn archive(cx) {
    let id = rest::param_int(cx, "id");
    guard id >= 1 && id <= cx.app.projects.len else { check(Error.NotFound, cx); }
    let project, err = archived(cx.app.projects[id - 1]);
    check(err, cx);
    cx.app.projects[id - 1] = project;
    rest::json(cx, 200, project);
}
```

</details>

## 3.2 What a rule does

A rule takes plain values, such as its domain's structs and numbers. It returns its
result and an `Error`, which is `Error.None` on success. From
[`routes-and-rules/projects/rules.goose`](routes-and-rules/projects/rules.goose):

```rust
// The project that input creates, with id, or why it can't.
fn new_project(input: CreateInput, id: i64) -> Project, Error {
    guard input.name.len > 0 else { return Project { .. }, Error.NameRequired; }
    guard input.name.len <= 64 else { return Project { .. }, Error.NameTooLong; }
    return Project { id: id, name: input.name, archived: false }, Error.None;
}

// p archived, or why it can't be.
fn archived(p: Project) -> Project, Error {
    guard !p.archived else { return p, Error.AlreadyArchived; }
    var q = p;
    q.archived = true;
    return q, Error.None;
}
```

A rule has no `cx`, so it can't read a header, answer, or fail the route, and it does no
I/O: everything it depends on is in its parameters. That includes the time. A rule that
depends on it takes `now`, and the job that calls the rule reads the clock once. From
[`lanes/entries/`](lanes/entries/):

```rust
// The entry that input creates, with id, or why it can't: it ends after it
// starts, and no later than now.
fn new_entry(input: CreateInput, id: i64, now: i64) -> Entry, Error {
```

```rust
    let e, err = entries::new_entry(u.input, w.entries.len + 1, time() as i64);
```

## 3.3 Which check goes where

The route rejects malformed requests, such as a missing field or a value that isn't a
number. Its extractors make these checks before the rule runs, and answer 400
`invalid_parameter`. The rule rejects well-formed requests that the domain refuses,
such as an empty name, or archiving a project that's already archived.

```text
POST /projects 400 {"error":"invalid_parameter","detail":"name: required"}
POST /projects 422 {"error":"project_name_required"}
POST /projects/1/archive 409 {"error":"project_already_archived"}
```

A malformed request is a bug in the client, and its 400 names the field. A refused
request comes from the user's input or the data's state, and its code names the rule
that refused it, in the domain's words. Each check is in one place: a rule doesn't
repeat what the extractors checked.

## 3.4 Why the split pays

A test calls a rule as a plain function, in microseconds, with no server, thread, or
database. From [`routes-and-rules/test.goose`](routes-and-rules/test.goose):

```rust
    let p, err = projects::new_project(projects::CreateInput { name: "goose" }, 1);
    assert(err == projects::Error.None && p.name == "goose" && !p.archived);
    let unnamed, why = projects::new_project(projects::CreateInput { name: "" }, 2);
    assert(why == projects::Error.NameRequired);
```

So each case of the domain's logic is tested where it's defined. A route's test covers
only what the route adds: its extractors and its answer
([Testing the application](../tutorial/16-testing.md)). A job on a lane calls the same
rules without a request. Changing a decision then changes one small function, which a
reviewer can judge on its own.

---

[Best practices](README.md) · Previous: [Layout by domain](layout.md) · Next:
[Errors](errors.md)
