# Middleware and stacks

An application's middleware is in `middleware.goose`, and its stacks, one per audience,
in `stacks.goose`. Every scope runs behind one stack. How middleware and stacks work,
and where each kind goes around `rest::route`, is on
[Middleware and scopes](../tutorial/07-middleware.md).

The code on this page is from [`middleware/`](middleware/).

## Middleware is named by a verb

Name a middleware for what it does: `authenticate`, `resolve_organization`,
`limit_rate`. Don't name it for the state it leaves, as a participle such as `authed` or
`rate_limited` would. From [`middleware/middleware.goose`](middleware/middleware.goose):

```rust
// Runs F with the user the bearer token names, or fails with 401.
inline fn authenticate<F>(cx) {
    // The token, or 401 for a request that has none.
    rest::bearer(cx) { token =>
        var user: i64 = 0;
        for s in SESSIONS {
            if s.token == token { user = s.user; }
        }
        guard user != 0 else { rest::invalid_token(cx); }
        // F is the block the caller gave: the next middleware, or the route.
        F(users::User { id: user });
    };
}
```

The sessions it reads are the ones the `auth` domain's routes open
([Layout by domain](layout.md)); the program keeps them in a global.

<details>
<summary>The other middleware, <code>resolve_organization</code></summary>

From [`middleware/middleware.goose`](middleware/middleware.goose):

```rust
// Runs F with the user as a member of the organization the X-Organization
// header names, or fails with 403 not_a_member. A scope's prefix can't hold
// a parameter yet, so the organization's id comes from a header.
inline fn resolve_organization<F>(cx, user: users::User) {
    let value, has = rest::header(cx, "X-Organization");
    rest::require(cx, "X-Organization", has);
    let organization = rest::int_of(cx, value, "X-Organization");
    var member = false;
    for s in SESSIONS {
        if s.user == user.id && s.organization == organization { member = true; }
    }
    guard member else { common::check(common::Error.NotAMember, cx); }
    F(members::Member { user: user.id, organization: organization });
}
```

</details>

A middleware runs code, and may answer instead of running its block. A verb says that
at the call site, `authenticate(cx) { user => ... }`, where a participle reads as a
condition already met.

## A block's parameter is named for what it's given

The parameter of a middleware's or a stack's block is named for the value it receives:
`user` from `authenticate`, `member` from `resolve_organization`.

The block's code uses that name throughout, so the name says what the route may rely
on: a `member` is a user already checked against the organization.

## A stack per audience

Write one stack for each audience the API has, and name it for that audience, singular,
with `_routes`: `public_routes`, `user_routes`, `member_routes`. From
[`middleware/stacks.goose`](middleware/stacks.goose):

```rust
// Routes anyone may call.
inline fn public_routes<F>(cx) {
    // The request's route: a fail from any depth inside, a stack's 401 or a
    // rule's 422, is answered here.
    rest::route(cx) { F(); };
}

// Routes a signed-in user calls.
inline fn user_routes<F>(cx) {
    rest::route(cx) {
        authenticate(cx) { user => F(user); };
    };
}

// Routes a member of the organization the request names calls.
inline fn member_routes<F>(cx) {
    rest::route(cx) {
        authenticate(cx) { user =>
            resolve_organization(cx, user) { member => F(member); };
        };
    };
}
```

Who may call a route decides what runs before it, so the audience is what tells two
stacks apart. A stack wraps routes as `rest::routes` does, and `_routes` says so where
it's called. Never name a stack `api` or another word that fits every route: it says
nothing about who calls them, and `api` is also the generated file's namespace
([Run it](../generator.md#run-it)).

A parameter in a scope's prefix, such as `/organizations/:id`, isn't supported yet, so
the member routes can't take the organization from their path. Until it is, the program
scopes them under `/organization`, and `resolve_organization` reads the organization's
id from the `X-Organization` header with `rest::header`.

## Every scope behind one stack

Each scope's routes, public ones included, run behind exactly one stack, which opens the
request's `rest::route`. `dispatch.goose` names each scope's stack, as
[All routing in one file](layout.md#all-routing-in-one-file) shows:
`public_routes(cx) { ... }` around `/health`, `user_routes` around `/settings`, and
`member_routes` around `/organization`.

Each route's audience is then named where its scope is, and a scope without a stack
stands out in review.

Middleware that every answer gets, such as `timed` and `cors`, goes once around
`rest::routes`, not in each stack, so that the 404s of `rest::otherwise` get it too.
From [`middleware/main.goose`](middleware/main.goose):

```rust
    rest::timed(cx) {
        rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) {
            rest::routes(cx) { cx =>
```

## Where middleware and stacks live

Keep the middleware in `middleware.goose` and the stacks in `stacks.goose`, beside
`dispatch.goose` ([Layout by domain](layout.md)).

Who may call what is then in two files, which a security review reads whole.

---

[Best practices](README.md) · Previous: [Errors](errors.md) · Next:
[Lanes and jobs](lanes.md)
