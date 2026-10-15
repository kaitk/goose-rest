# 034: Middleware stacks of the program's own

Status: todo (asked for 2026-10-15)

Middleware composes by nesting blocks, so each one a program adds takes every handler a
level deeper: timing, CORS, the route, a token, a tenant, and a rate limit make six
levels around every scope's routes, written again at each. An `inline fn` that nests
them and passes its own block on gives the program one name for the whole stack, and
each scope one level:

```rust
inline fn api<F>(cx) {
    rest::timed(cx) {
        rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) {
            rest::route(cx) {
                rest::bearer(cx) { token =>
                    guard token == "secret" else { rest::invalid_token(cx); }
                    F(token);
                };
            };
        };
    };
}

api(cx) { token => projects(cx, token); };
```

This works today, and costs what the nesting written out does: spike 04 found that a
block passed on by name still inlines into one C function, and the benchmark server's
`authed` is this shape. Nothing checks it, though, and the tutorial doesn't show it. A
stack is code, not a value: Goose's blocks are compile-time arguments, so there is no
list of middleware to build at run time, as Actix's `wrap` or Tower's `Layer` builds
one.

A stack keeps the rules the nesting has: middleware that adds fields to every answer
goes outside `rest::route` and middleware that can fail inside it; a request opens one
`rest::route`, so a stack says whether it opens it, and code inside one that does
opens none; and a stack is an `inline fn`, as a plain `fn` with a block of routes stays
a call and keeps what's around it out of line.

## Acceptance criteria

- [ ] `test/inline_route.goose` covers a stack calling a stack, two levels, whose block
      takes an argument, and its check still finds one handler function in the C
- [ ] Tutorial page 7 has a section on a stack of the program's own: the example, why
      (one level per scope, however many middleware), and the three rules above
- [ ] Page 7 gives the naming convention, so a call reads as what holds inside it
      (2026-10-15): a middleware of the program's own is named for that, an adjective
      or participle, as `rest::timed` is (`authed`, `tenanted`, `limited`); a stack is
      named for the part of the API it serves, a noun (`public`, `api`, `admin`,
      `partner`); a block's parameter for what it is given (`token`, `tenant`). Page
      7's `tenant` becomes `tenanted`, and the example's stack is `api`
- [ ] The reference's "Middleware" section points to it
- [ ] Open, recorded here when decided: whether the generator takes a program's stack
      per OpenAPI security scheme, rather than nesting fixed calls per operation
