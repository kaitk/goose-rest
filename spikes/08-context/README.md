# 08: A context that holds the router and the worker's state

Checks whether hand-written routes can take the context alone. Today a route's function
takes three things, `cx`, the program's state, and goose-http's `http::Router`:
`fn v1(cx, app: App&, r: http::Router&)`, with `plod::param_int(cx, r, "id")` and
`plod::otherwise(cx, r)` (task 015). Here the context, `plod::Cx<S, A>`, holds a
reference to the worker's state, `app`, beside the per-request `state`, and an optional
reference to a router. `plod::routes(cx) { cx => ... }` builds the router and hands its
block a copy of the context that holds it, so `plod::on`, `plod::scope`, `plod::param`,
and `plod::otherwise` take `cx` alone. A program that never calls `routes`, such as one
served by the generated router, builds no router.

Also checks a function that types its context through an alias,
`type Cx = plod::Cx<St, App>;`.

Goose: commit `f114b5a`, the pin, with the same output as on release `v2026.2` (`3ee3871`), `v2026.1` (`ac759c3`) and `bc3c1f1`. goose-http: `ebb4238`, with the same output as at `v0.5.4`, `v0.5.3`, `v0.5.2`, `cbffc2a`, `5701a0d`, `b5f82a2`, `v0.4.3`, `v0.4.2`, `v0.4.1`, `v0.4.0`, `ff18ecc`, `v0.3.6`, `6e57c42`, `v0.3.5`, `v0.3.4`, `v0.3.3`, `v0.3.2`, `v0.3.1`, and `cb57a0b`.

```sh
GOOSE=<build>/goose
$GOOSE main.goose
```

## Verdict: works, with one workaround

```text
200 ok
200 goose has 3 projects; this is 42
204 deleted 7 of goose
405 allow: GET, HEAD, DELETE
404 not_found
requests seen: 5
```

(`expected.txt` has a blank line after each answer.)

- The block's parameter may be named `cx`, hiding the outer one, so a route's code reads
  as it would without `routes`.
- `plod::on` adds a matched path's methods to the router through the context, so
  `plod::otherwise` answers 405 with the `Allow` of every route tried.
- `cx.app` reaches the worker's state, and `cx.state.seen++` writes the per-request
  state, from functions that take `cx` alone, untyped or typed through the alias.

The workaround: `plod::scope` narrows the router's path, and that store, written in
`scope` through `var r .= cx.router`, is refused. The checker charges it to everything the
context's other references reach, the caller's `out` among them
([findings](../../docs/goose-findings.md#a-store-through-an-optional-field-is-charged-to-the-structs-other-references)).
The same store in `narrowed(r: http::Router&)`, which `scope` calls, is accepted.

Three other checks for task 015, on the same commit, each refused as the spec says:

- `cx.text(...)` for `plod::text(cx, ...)` from a program's namespace: UFCS looks in the
  caller's namespace, not the type's
  ([findings](../../docs/goose-findings.md#ufcs-doesnt-reach-the-namespace-of-the-receivers-type)).
- `let v: T = plod::take(cx)`: "cannot infer all generic parameters", so `T` stays
  explicit, `plod::take<T>(cx)`.
- `return plod::route(cx) { ... };`: "cannot return a valueless expression"
  ([findings](../../docs/goose-findings.md#a-function-cant-return-a-valueless-call)).
