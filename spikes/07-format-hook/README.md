# 07: The `format` hook from `rest::json`

Checks the design's `rest::json(cx, status, v)`, which writes `v` by calling
`format(out, v)`. `json` is generic and in namespace `rest`. The overloads are declared
where the types are: in `app` by hand, and in `api` as the generator would write them,
with `json::format_*`. Each namespace has a type that nests another with its own
overload. `rest` declares a `format` overload of its own, for its error body.

Spike 01 found that a generic body resolves names where it's defined (spec §11.1), so
`rest::take` can't see `app::from_request`. Spec §11.1 makes the `format` hook the one
type-directed exception: the overload is looked up in the namespace that declares the
type, then globally (§3.7). This spike checks that the compiler does so.

Goose commit: `46356c2`, with the same output as on `a6249a4`.

```sh
GOOSE=<build>/goose
$GOOSE main.goose
$GOOSE -O2 -o main.c main.goose           # the generated C
grep -E '^static .*_g[0-9]*\(' main.c | grep -v ';'
```

## Verdict: works, with no workaround

```text
200 {"id":42,"owner":{"id":7,"name":"ada"},"name":"goose"}
200 {"id":3,"lead":{"id":9,"admin":true,"name":"say \"hi\""}}
200 [{"id":1,"name":"a"}, {"id":2,"name":"b"}]
200 app::Session { 1, 2 }
404 {"error":"not_found"}
```

- `rest::json` finds `app::format` for `app::Project` and `api::format` for
  `api::Team`, though neither namespace is visible from `rest`'s body.
- A nested value renders through its own type's overload, whether the outer overload
  passes it to the multi-argument `format(out, "...", p.owner, ...)` (`app`) or calls
  `format(out, t.lead)` (`api`).
- `rest`'s own `format` overload, for `rest::Failure`, doesn't hide the others. Overload
  sets don't merge across namespaces (§11.1), but the hook's lookup follows the type,
  not the namespace of the call (§3.7).
- An array renders as `[a, b]` with each element through its overload: valid JSON, with a
  space after each comma.
- At `-O2`, the C keeps `main_g` as its only Goose function: `json` and every overload
  are inlined.

The design's `rest::json` and its `format` hook stand as written. No declaration in
`rest`'s namespace is needed, unlike `from_request` (spike 01).

## Two things the writer must do itself

A type with no overload still compiles. The builtin renders it structurally, as
`app::Session { 1, 2 }`, which isn't JSON. Nothing in Goose can require an overload,
because the builtin accepts every type. The generator writes one for each schema type.
For hand-written types, a test of each route's body catches a missing one. The
alternative, a hook of goose-rest's own such as `rest::write_json`, would make a missing
writer a compile error, but the application would then have to declare it in `rest`, as
spike 01's extractors are.

The builtin doesn't escape for JSON. A `u8` array at the top of an argument is appended as
it is, and one nested in a struct with no overload is quoted with Goose's escapes. String
fields go through `json::format_string`, as `api.goose` does: `say "hi"` comes out as
`"say \"hi\""`. `app.goose` writes its names unescaped, which is only safe for text
known to need no escaping.

`json` takes `v` untyped. `v: const T&` refuses a struct literal ("cannot pass
api::Team as const T&"), as spec §3.8 says for `&` of a temporary, so a handler couldn't
write `rest::json(cx, 200, Project { ... })`.
