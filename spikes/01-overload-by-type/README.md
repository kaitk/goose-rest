# 01: Overload chosen by a type parameter

Checks whether `take<T>(cx)`, which declares `var v = default<T>()` and calls
`from_request(cx, v)`, resolves that call by `T` in each instantiation, and hands `v`
to a trailing block: `take<Session>(cx) { s => ... }`. This is the extractor design in
[the decisions](../../docs/decisions.md#extractors).

Goose: commit `f114b5a`, the pin, with the same output as on release `v2026.2` (`3ee3871`), `v2026.1` (`ac759c3`), `bc3c1f1` and `a6249a4`.

```sh
GOOSE=<build>/goose
$GOOSE main.goose          # one namespace
$GOOSE cross/main.goose    # take in namespace plod, extractors in app
```

## Verdict: works, with a workaround across namespaces

In one namespace, `main.goose` prints `session 7`, `page 3 size 20`, and `both 7 3`
(nested). Each instantiation is checked with concrete `T`, so overloading picks
`from_request(cx, v: Session&)` or `from_request(cx, v: Page&)`.

Across namespaces it fails, as the spec says it should. A generic body resolves names
where it is defined (spec §11.1), and there is no argument-dependent lookup, so
`plod::take` doesn't see `app::from_request`:

```rust
namespace plod;
fn take<T, F>(cx: Cx&) { var v = default<T>(); from_request(cx, v); F(v); }

namespace app;
fn from_request(cx: plod::Cx&, v: Session&) { v.user = 7; }
fn handle(cx: plod::Cx&) { plod::take<Session>(cx) { s => print(s.user); }; }
```

```text
plod.goose:9: error: unknown function: from_request
  in fn plod::take<T = app::Session, F = {block at app.goose:13:29}>(plod::Cx&) ...
```

Workaround (`cross/`): the application declares its extractors into the `plod`
namespace, `fn plod::from_request(cx: plod::Cx&, v: app::Session&)`. They join the
overload set of plod's built-in extractors (`plod::Query` here). Inside such a
declaration, names resolve in `plod`, so the application's own names are qualified
(`app::Session`, `app::user_of`). A generator can write these declarations.
`cross/main.goose` prints `session 7`, `page 3`, and `query a=1`.

## T can't be inferred

`T` must be given explicitly. Neither a typed block parameter,
`take(cx) { s: Session => ... }`, nor a named function, `take(cx, show)` with
`fn show(s: Session)`, binds it:

```text
candidate take at ...: 1 function value(s) for 2 unbound generic parameter(s)
```

The spec infers type arguments only from argument types (§7.7), so this is as
specified.

## Caveat

`take` passes `v`, a local, to the block, which gets a copy (goose-http finding "A
block given a local struct writes to a copy of it"). That's fine for extractors the
handler only reads. One that the block must change has to hold a reference.
