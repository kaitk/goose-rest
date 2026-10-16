# Routes and rules

A route is where HTTP ends: it reads the request and writes the answer. A rule is where
the domain's decisions are: it takes typed values and returns a result or an error. The
two live in a domain's `routes.goose` and `rules.goose`
([Layout by domain](layout.md#the-same-files-in-every-domain)).

The code on this page is from [`routes-and-rules/`](routes-and-rules/), whose projects
live in the worker's memory in place of a database.

## A route extracts, calls one rule, and answers

A route reads what it needs from the request, calls one rule or one service job, and
answers with the result or the error. From
[`routes-and-rules/projects/routes.goose`](routes-and-rules/projects/routes.goose):

```rust
fn create(cx) {
    let name, has = rest::form(cx, "name");
    rest::require(cx, "name", has);
    let project, err = new_project(CreateInput { name: name }, cx.app.projects.len + 1);
    check(err, cx);
    cx.app.projects.push(project);
    rest::json(cx, 201, project);
}
```

`check` fails the route with the error's status and code, or returns for `Error.None`
([Errors](errors.md#each-domains-codes-in-one-place)). The program stores the project in
the worker's list; with a database, the route asks a service job instead, which applies
the same rule.

A route kept to this shape fits on one screen, and the decisions it leads to are in
functions that a test calls without a request.

## The route checks the request, the rule checks the domain

The route rejects a request that is malformed: a field missing, or not a number. The
extractors do that, with 400 `invalid_parameter`, before the rule runs. The rule rejects
a request that is well formed but that the domain refuses: an empty name, a project
already archived.

```text
POST /projects 400 {"error":"invalid_parameter","detail":"name: required"}
POST /projects 422 {"error":"project_name_required"}
POST /projects/1/archive 409 {"error":"project_already_archived"}
```

A malformed request is a bug in the client, and its 400 names the field. A refused
request comes from the user's input or the data's state, and its code says which rule refused it, in the
domain's words. Each check is in one place: a rule doesn't check what the extractors
did.

## A rule takes typed input, and has no `cx`

A rule takes plain values, its domain's structs and numbers, and returns its result and
an `Error`, `Error.None` when it succeeds. From
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

Without `cx`, a rule can't read a header, answer, or fail the route, so everything it
depends on is in its parameters. A test calls it as a plain function, and a service job
calls the same rule on its own thread, where there is no request.

## Work that waits goes to a service, one job per route

A route that needs the database asks a service with `rest::ask`, once, and the service
does the whole use case as one job in one transaction, applying the domain's rules. The
job's function is in the domain's `service.goose`.

One wait per route gives one time limit, one place where a full mailbox refuses work,
and one transaction per use case
([Why one job per route](../tutorial/13-waiting.md#why-one-job-per-route)).

---

[Best practices](README.md) · Previous: [Layout by domain](layout.md) · Next:
[Middleware and stacks](middleware.md)
