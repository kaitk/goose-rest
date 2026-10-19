# 02: Early exit from middleware blocks

Checks that middleware written as `fn with_auth<F>(cx: Cx&) { guard ok else { answer
401; return; } F(session) }`, nested three deep around a handler body, skips the
inner blocks and the body when it answers. Also checks that a plain `return` in the
innermost block returns from the enclosing named function, as spec §7.6 says.

Goose: commit `f114b5a`, the pin, with the same output as on release `v2026.2` (`3ee3871`), `v2026.1` (`ac759c3`), `bc3c1f1` and `a6249a4`.

```sh
GOOSE=<build>/goose
$GOOSE main.goose
```

## Verdict: works

```text
200 ok returned 5 trace[handler body after-role after-auth end]
401 unauthenticated returned 5 trace[handler after-auth end]
403 origin returned 5 trace[handler end]
404 no id returned -1 trace[handler body
```

- On the 401 path, neither `with_role`'s block nor the body runs.
- The innermost block's `return -1;` leaves `handler` from three blocks down. No code
  after any block runs, and `handler` returns `-1`.
- A middleware's own `return` leaves only the middleware. Statements after the
  middleware call in `handler` still run (`after-auth`, `end` on the 401 path). So a
  middleware call should be the last statement of whatever it guards. Code after it
  must check `cx.status`, or go inside the block.
