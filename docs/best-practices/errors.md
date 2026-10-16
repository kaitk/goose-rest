# Errors

Every error an application answers has one shape, and each domain lists the errors it
answers in one file, `errors.goose`, with the status and code of each.

The code on this page is from [`errors/`](errors/).

## One error shape for the whole API

Answer every error in goose-rest's shape, `{"error": code}`, which the framework's own
errors already use ([Errors](../reference.md#errors)). If the API needs another shape,
write it once, as the `rest::error_body` overload in `common/errors.goose`
([Answers and errors](../tutorial/03-errors.md#errors)).

A client then reads every error the same way, whether a route or goose-rest answered
it: a 404 from `rest::otherwise`, a 413 for a body past its limit, or a project the
domain refuses.

## Each domain's codes in one place

A domain's `errors.goose` holds its `Error` enum, a variant per way the domain refuses,
and `check`, a case function per variant that fails the route with its status and code.
From [`errors/projects/errors.goose`](errors/projects/errors.goose):

```rust
enum Error { None, NotFound, NameTaken, Archived }

// Fails the route with e's status and code, or returns for Error.None. A
// case function per variant: check(e, cx) runs the one for e's variant, and
// the program doesn't compile while a variant has none.
fn check(e: Error.None, cx) {}
fn check(e: Error.NotFound, cx) { rest::fail(cx, 404, "project_not_found"); }
fn check(e: Error.NameTaken, cx) { rest::fail(cx, 409, "project_name_taken"); }
fn check(e: Error.Archived, cx) { rest::fail(cx, 409, "project_archived"); }
```

A rule returns an `Error` ([Routes and rules](routes-and-rules.md#what-a-rule-does)),
and the route passes it to `check`:

```rust
fn show(cx) {
    let id = rest::param_int(cx, "id");
    // Ends the route with the rule's refusal, or goes on for Error.None.
    check(readable(id), cx);
    rest::text(cx, 200, str("project ", id));
}
```

Every code the domain answers is then in one file, which a client's developer can read
whole. Rules stay free of HTTP: they name the refusal, and `check` gives it a status.
Because the compiler requires a `check` for every variant, a new variant can't go out
without a status and code.

<details>
<summary>The projects' routes, with a domain's and a shared error</summary>

From [`errors/projects/routes.goose`](errors/projects/routes.goose):

```rust
fn routes(cx) {
    if rest::on(cx, "GET", "/:id") {
        show(cx);
    } else if rest::on(cx, "DELETE", "/:id") {
        remove(cx);
    } else {
        rest::otherwise(cx);
    }
}

fn show(cx) {
    let id = rest::param_int(cx, "id");
    // Ends the route with the rule's refusal, or goes on for Error.None.
    check(readable(id), cx);
    rest::text(cx, 200, str("project ", id));
}

fn remove(cx) {
    let role, has = rest::header(cx, "X-Role");
    guard has && role == "admin" else { common::check(common::Error.NotAnAdmin, cx); }
    check(removable(rest::param_int(cx, "id")), cx);
    rest::empty(cx, 204);
}
```

</details>

## A code names the entity and what went wrong

Write a code in snake_case, starting with the entity it's about: `project_not_found`,
`project_name_taken`, `project_archived`.

Codes then stay unique across domains without a registry, and a client can match on
one without reading the status.

## Shared codes go in `common/errors.goose`

An error that more than one domain answers, or that middleware answers, goes in
`common/errors.goose`, laid out as a domain's. From
[`errors/common/errors.goose`](errors/common/errors.goose):

```rust
enum Error { None, NotAMember, NotAnAdmin }

// Fails the route with e's status and code, or returns for Error.None.
fn check(e: Error.None, cx) {}
fn check(e: Error.NotAMember, cx) { rest::fail(cx, 403, "not_a_member"); }
fn check(e: Error.NotAnAdmin, cx) { rest::fail(cx, 403, "not_an_admin"); }
```

```rust
    guard has && role == "admin" else { common::check(common::Error.NotAnAdmin, cx); }
```

As with other shared code, an error moves here when a second domain answers it
([Shared code moves to `common/`](layout.md#shared-code-moves-to-common)).

## Choosing the status code

| Status | When | From |
|---|---|---|
| 400 | The request is malformed: a field missing, or not a number | The extractors, as `invalid_parameter` or `invalid_body` |
| 401 | No credentials, or credentials that aren't valid | `rest::bearer`, `rest::invalid_token` |
| 403 | Valid credentials, for something they don't allow | `common/errors.goose`: `not_a_member` |
| 404 | No such entity, or none the caller may see | The domain: `project_not_found` |
| 409 | The entity's state refuses the change | The domain: `project_archived`, `timer_already_running` |
| 422 | Well-formed input that a rule refuses | The domain: `project_name_required` |

A client can then decide from the status alone whether to fix the request, sign in
again, or show the user why the domain refused.

---

[Best practices](README.md) · Previous: [Routes and rules](routes-and-rules.md) · Next:
[Middleware and stacks](middleware.md)
