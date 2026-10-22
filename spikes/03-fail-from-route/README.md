# 03: `return ... from` a library wrapper

Checks the design's `plod::fail`. In namespace `plod`, `route<F>(cx)` calls its block,
and `fail(cx, status, code)` does `return Failure { ... } from route`. The application,
in namespace `app`, calls `fail` two and three calls below the handler that `route`'s
block calls. `plod::serve` then writes the error that `route` returns.

Goose: commit `f114b5a`, the pin, with the same output as on release `v2026.2` (`3ee3871`), `v2026.1` (`ac759c3`), `bc3c1f1` and `a6249a4`.

```sh
GOOSE=<build>/goose
$GOOSE main.goose
```

## Verdict: works, with a workaround for codes that aren't literals

```text
42: 200 {"id":42,"name":"goose"}
0: 404 {"error":"project_not_found"}
13: 403 {"error":"forbidden"}
7: 400 {"error":"/projects"}
```

`fail` is called from `app::find_project` (three calls below the block) and
`app::load` (two calls below), and unwinds to `route` from another namespace. The
handler's partial output is never written, and `serve` answers with the error. An
application function that calls `fail` from anywhere outside `route` is a compile
error, `call to get_project requires an enclosing call of route`. So is a non-generic
one that nothing calls: it is checked anyway, outside any `route`.

## The workaround

A long-distance return can carry a slice only of static data. `Failure { status, code:
const u8[:] }` compiles while every `code` is a literal. A code taken from the request,
`plod::fail(cx, 400, cx.path)`, is refused, as the design's `plod::invalid(r, key,
...)` would be. A bare slice is refused too, as the minimal program shows:

```rust
fn route(path: const u8[:]) -> const u8[:] {
    check(path);
    return "";
}

fn check(path: const u8[:]) { return path from route; }

fn main() {
    var p: u8[>..] = [];
    p.append("/x");
    print(route(p));
}
```

```text
lr2.goose:6: error: a long-distance return may only carry references to globals or static data
```

`p` outlives the call of `route`, and spec §7.9 states no such limit, so this is the
compiler's restriction rather than the spec's. Workaround, used here: `Failure` holds
its code inline, `code: u8[..32]`, and so carries no reference.
