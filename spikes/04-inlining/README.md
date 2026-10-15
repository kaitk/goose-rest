# 04: Inlining to straight-line code

Checks whether three nested middleware blocks (`rest::with_cors`, `with_auth`,
`with_role`, as in spike 02) around a `rest::route` wrapper with `rest::fail` (as in
spike 03) compile to one function, with no function pointers and no call frame per
layer.

Goose: release `v2026.1` (`ac759c3`), with the same output as on `bc3c1f1` and `a6249a4`. C compiler: Clang 21.1.8, x86-64 Linux.

```sh
GOOSE=<build>/goose
$GOOSE main.goose                         # runs: 200, 401, 403, 404
$GOOSE -O2 -o main.c main.goose           # the generated C
grep -E '^static .*_g[0-9]*\(' main.c | grep -v ';'
$GOOSE -O2 -o forward.c forward.goose     # the reduced case below
```

## Verdict: works, with a workaround

With `main.goose` as it is, Goose inlines everything: `optimized -O2: 12 inlined`, and
the only Goose function left in the C is `main_g`. Each middleware's early answer is a
`goto` past the rest of the nesting. `rest::fail`'s `return ... from run` costs no
discriminant: it becomes an assignment to `route`'s result and a `goto`:

```c
if (!(t32)) {                       /* with_auth: cookie != "ok" */
    ...
    (*t35) = 401;
    ...
    goto L29;
}
...
        t52.status_g = 404;         /* rest::fail(404, "not_found") in find */
        ...
        f_g = t52;
        goto L47;
```

The C contains no function-pointer calls outside the runtime's thread start.

## The workaround: wrap a forwarded function value in a block

`rest::route` originally passed its block on by name, `let f = run(F);`. Goose then
inlines nothing on the path: the C keeps `handler_g`, `rest_with_cors_g4`,
`rest_with_auth_g4`, `rest_with_role_g4`, `rest_route_g4`, and `rest_run_g4`. Each is a
direct call that passes free variables as pointers, plus an `if (gs_rf)` check after
`run`. Declaring the middleware `inline fn` changes nothing. Writing
`run() { F() }` instead inlines all of it. `forward.goose` is the reduced case:

```goose
fn route<F>(cx: Cx&) { let r = run(F); cx.status = r; }   // 0 inlined
fn route<F>(cx: Cx&) { let r = run() { F() }; cx.status = r; }   // 5 inlined, only main_g left
```

With the forwarding form, clang `-O2` still inlined the five static functions into
`handler_g`: one frame, no calls but `gs_memeq_long` and `gs_fmt_i64`. So the cost
depends on the C compiler, and gcc (goose-http's choice) was not checked here. The
stdlib's `exception::try` forwards its body the same way (`handler<E>(Body)`).

Since Goose `b6377db` ("Inline calls that pass a function value by name"), both forms
inline all five: on `46356c2`, `forward.goose`'s `-O2` C keeps only `main_g`.
