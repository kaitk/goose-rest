# 4. Errors

The application uses one shape for every error answer. Each domain lists its errors
in `errors.goose`, with a status and code for each.

The code on this page is from [`errors/`](errors/).

## 4.1 One error shape for the whole API

Answer every error in goose-rest's shape, `{"error": code}`, which the framework's own
errors already use ([Errors](../reference.md#5-errors)). If the API needs another shape,
write it once, as the `rest::error_body` overload in `common/errors.goose`
([Answers and errors](../tutorial/03-errors.md#errors)).

A client then reads every error the same way, whether a route or goose-rest answered
it: a 404 from `rest::otherwise`, a 413 for a body past its limit, or an operation on a
project that the domain refuses.

## 4.2 Each domain's codes in one place

A domain's `errors.goose` holds its `Error` enum, with a variant for each reason the
domain refuses an operation. It also holds a `check` case function for each variant,
which fails the route with that variant's status and code.
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

A rule returns an `Error` ([Routes and rules](routes-and-rules.md#32-what-a-rule-does)),
and the route passes it to `check`:

```rust
fn show(cx) {
    let id = rest::param_int(cx, "id");
    // Ends the route with the rule's refusal, or goes on for Error.None.
    check(readable(id), cx);
    rest::text(cx, 200, str("project ", id));
}
```

Every error code the domain answers is then in one file that a client developer can
read in full. Rules stay free of HTTP: they name the refusal, and `check` gives it a
status. The compiler wants a `check` for every variant, so each new variant gets a
status and code.

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

## 4.3 A code names the entity and what went wrong

Write a code in snake_case, starting with the entity it's about: `project_not_found`,
`project_name_taken`, `project_archived`.

Codes then stay unique across domains without a registry, and a client can match on
one without reading the status.

## 4.4 Shared codes go in `common/errors.goose`

An error that more than one domain answers, or that middleware answers, goes in
`common/errors.goose`, laid out like a domain's. From
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
([Shared code moves to `common/`](layout.md#25-shared-code-moves-to-common)).

## 4.5 Choosing the status code

| Status | When | From |
|---|---|---|
| 400 | The request is malformed: a field is missing, or a value isn't a number | The extractors, as `invalid_parameter` or `invalid_body` |
| 401 | No credentials, or credentials that aren't valid | `rest::bearer`, `rest::invalid_token` |
| 403 | The credentials are valid but don't allow the operation | `common/errors.goose`: `not_a_member` |
| 404 | No such entity, or none the caller may see | The domain: `project_not_found` |
| 409 | The entity's state prevents the change | The domain: `project_archived`, `timer_already_running` |
| 422 | Well-formed input that a rule refuses | The domain: `project_name_required` |

A client can then decide from the status alone whether to fix the request, sign in
again, or show the user why the domain refused.

---

[Best practices](README.md) · Previous: [Routes and rules](routes-and-rules.md) · Next:
[Middleware and stacks](middleware.md)
