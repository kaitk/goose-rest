# Goose findings

Goose compiler and stdlib gaps found here, in the format of goose-http's
`docs/goose-findings.md`. Each names the Goose commit it was found on, and the one it
was last checked on. A gap fixed upstream leaves this file with the pin move that
takes the fix.

The entries come in two parts: [bugs](#bugs), where Goose does something wrong or other
than its spec says, then [feature requests](#feature-requests), for what it lacks. Each
part runs from the least work a fix is expected to take to the most, so the cheap fixes
come first. The order is an estimate from reading the compiler. Place a new entry where
its expected work puts it.

## Bugs

### A case-function call missing a variant doesn't name it

Found on `a6249a4`, spike 06. Status: open; unchanged on `46356c2`

A call dispatched to case functions (§8.2) that lack an overload for one variant fails
to compile, as it should, but the error is the generic one for no matching overload: it
lists the cases there are and doesn't name the one missing. §8.2 checks exhaustiveness
"exactly like `match`", and a `match` without that arm says `match does not cover
variant Waiting.None`. Expected: the same message for both.

    enum Waiting { None, Report { org: i64 }, Export { org: i64 } }

    fn resume(w: Waiting.Report) { print("report ", w.org); }
    fn resume(w: Waiting.Export) { print("export ", w.org); }

    fn main() {
        let w: Waiting = Waiting.Report { org: 3 };
        resume(w);
    }

    error: no matching overload for call to resume
      candidate resume at missing_case.goose:5: argument 1: cannot pass Waiting as Waiting.Report
      candidate resume at missing_case.goose:6: argument 1: cannot pass Waiting as Waiting.Export

Workaround: none needed; compare the candidates with the enum's variants.

### A block given a local struct gets a copy of it

Found on `a6249a4`, task 005. Status: open; still prints 0 on `46356c2`. Recorded in
goose-http's findings ("A block given a local struct writes to a copy of it", found on
`5c83a5a`)

`rest::json_body` hands its block a `json::Reader` it declared, `R(r, cx.scratch)`, and
the block's reader advanced a copy: `json::finish` then found the whole body unread and
reported "trailing input" at byte 0. Nothing warns: the program compiles and runs, and
its writes are lost. Expected: the block's parameter binds the local itself, as an
untyped function parameter does.

    struct Cursor { pos: i64 }

    fn advance(c: Cursor&) { c.pos++; }

    fn twice<F>() {
        var c = Cursor { pos: 0 };
        F(c);           // F(&c) passes the local itself
        F(c);
        print(c.pos);   // 0
    }

    fn main() { twice() { it => advance(it); }; }

Workaround: pass the local as a reference, `R(&r, cx.scratch)`, which is shorter than
goose-http's struct holding a reference.

### A store through an optional field is charged to the struct's other references

Found on `46356c2`, spike 08. Status: open

A function that writes through a binding of a struct's optional reference field is taken
to store into whatever any of the struct's references lead to. Called on a struct whose
optional field points at a local, the call is refused when another field points at the
caller's storage, though the store goes only into the local. The same store in a
function that takes the local's type by reference is accepted. Expected: the store is
charged to the optional field's target alone, as the reference parameter's is.

    import std;
    struct Inner { path: const u8[:] }
    struct Outer { log: u8[>..]&, inner: Inner? = null }

    fn trim(o) {
        var r .= o.inner;
        guard r else { return; }
        r.path = r.path[1..];       // refused at the call below
    }

    fn with_inner(o: Outer&) {
        var i = Inner { path: "/abc" };
        var c = Outer { log: o.log, inner: i };
        trim(c);
        o.log.append(i.path);
    }

    fn main() {
        var log: u8[>..] = [];
        var o = Outer { log: log };
        with_inner(o);
        print(log);
    }

    error: call trim stores a reference rooted at i into what its parameter o leads to,
    which may be the caller's storage behind o, which i does not outlive (§9.2)

goose-rest meets it with a context that holds the router a route's block adds: `rest::scope`
narrows the router's path through the context's optional field.

Workaround: move the store into a function that takes the field's type by reference,
`fn cut(r: Inner&) { r.path = r.path[1..]; }`, called as `cut(r)`.

### A long-distance return can't carry a slice a caller passed in

Found on `a6249a4`, spike 03. Status: open; still fails on `46356c2`

`return E from f` refuses an `E` that holds a slice passed into the returning function,
even when the slice came from outside `f`'s call and so outlives it. The stdlib's
`exception` section documents the limit ("references carried by a long-distance return
must point to globals or static data"), but §7.9 doesn't: it says only that `E`'s
destination follows §7.3. Expected: a slice rooted outside `f`'s call may travel with
the return, as it may in an ordinary return from `f`, or the spec states the limit.

    fn route(path: const u8[:]) -> const u8[:] { check(path); return ""; }
    fn check(path: const u8[:]) { return path from route; }
    fn main() { var p: u8[>..] = []; p.append("/x"); print(route(p)); }

    error: a long-distance return may only carry references to globals or static data

Workaround: carry owned bytes, `u8[]` built with `str(path)`, as `exception::throw`'s
docs advise; `copy` refuses a slice. A limited array such as `u8[..32]` works too.

## Feature requests

### A function can't return a valueless call

Found on `46356c2`, task 015. Status: open

`return f();` is refused when `f` returns nothing, so a function that ends on such a
call writes it and then `return;`. Expected: `return` of a valueless expression in a
function without a result, as C++ and Rust allow, so a branch that hands off can end in
one statement.

    import std;
    fn wrap<F>() { F(); }
    fn f() { return wrap() { print("in"); }; }
    fn main() { f(); }

    error: cannot return a valueless expression

goose-rest's plan wrote each generated route as `return rest::route(cx) { ... };`.

Workaround: `rest::route(cx) { ... };` and then `return;`, as the generated router does.

### An error inside a generic function lists every frame up to main

Found on `46356c2`, task 014. Status: open

An error in a specialized function is followed by the whole chain of instantiations
that led to it, one line per frame, up to `main`. A frame instantiated through a block
parameter lists where that block's own caller was instantiated too, so the chain runs
through every generic function between the call and `main`. Expected: a shorter chain by
default, such as the first few frames and the last, with an option for all of them.

    import std;

    fn handler_call(x) { missing_handler(x); }
    fn route<F>(x) { F(x); }
    fn dispatch(x) { route(x) { y => handler_call(y) }; }
    fn loop3<H>(x) { H(x); }
    fn loop2<H>(x) { loop3(x) { y => H(y) }; }
    fn loop1<H>(x) { loop2(x) { y => H(y) }; }
    fn serve<H>(x) { loop1(x) { y => H(y) }; }

    fn main() {
        serve(1) { x => dispatch(x) };
    }

    main.goose:3: error: unknown function: missing_handler
      in fn handler_call(literal i64) instantiated from main.goose:5
      in fn route<F = {block at main.goose:5:27}>(literal i64) instantiated from main.goose:5
      in fn dispatch(literal i64) instantiated from main.goose:12
      in fn loop3<H = {block at main.goose:7:27}>(literal i64) instantiated from main.goose:7
      in fn loop2<H = {block at main.goose:8:27}>(literal i64) instantiated from main.goose:8
      in fn loop1<H = {block at main.goose:9:27}>(literal i64) instantiated from main.goose:9
      in fn serve<H = {block at main.goose:12:14}>(literal i64) instantiated from main.goose:12
      in fn main() instantiated from main.goose:11

goose-rest meets it when a handler the schema names is missing: the generated
`dispatch` is generic in `cx` and `state`, and runs inside `rest::serve`'s block, which
runs inside goose-http's event loop, so the error lists 18 frames, 8 of them in
goose-http's loop (`http::answer`, `http::pump`, `http::mail_take`, and so on). The
generated code can't shorten it: a named function that calls the handler would be
generic in `cx` too, and get the same chain.

Workaround: read the first lines. The error's line in `api_gen.goose` names the call,
and the first frames name the operation (tutorial section 6).

### A function called once isn't inlined past a size

Found on `a6249a4`, task 006. Status: open, reported as
[aardappel/goose#33](https://github.com/aardappel/goose/issues/33) (2026-10-13); still
fails on `46356c2`. The limit is intended: inlining every single-caller function made
`main` too large for the C compiler. The maintainer proposed (2026-10-13) a larger node
limit, or always inlining a function value called once; neither is decided.

A function with one call site stays a call once its body passes a size, at `-O1` and
`-O2`. With 15 of the statements below, `handle` is inlined into `main`; with 16, the C
keeps `handle_g` and calls it. Called from inside a loop, whose size allowance is four
times larger, it's inlined again.

    import std;
    import os;

    fn handle(buf: u8[>..]&, id: i64) {
        if id == 0 { buf.append(str("v", id, "0")); }
        if id == 1 { buf.append(str("v", id, "1")); }
        // ... the same for 2 to 14
        if id == 15 { buf.append(str("v", id, "15")); }
    }

    fn main() {
        var b: u8[>..] = [];
        handle(b, args().len - 1);
        print(b);
    }

goose-rest meets it in a handler behind middleware: a block-taking function such as
`rest::cors`, given the handler's routes as its block, passes the size at once. It then
stays a call that reaches the handler's locals through pointers, and the handler stays
a call around it. `inline fn` makes each one inline.

Workaround: goose-rest's functions that take a block are `inline fn` (`route`,
`attempt`, `cors`, `bearer`, `timed`, `json_body`), so the middleware, the route, and
the code that fails all fold into the handler, which may stay one function of its own
(`test/inline_route.goose`).

### UFCS doesn't reach the namespace of the receiver's type

Found on `46356c2`, task 015. Status: open

`x.f(a)` looks `f` up in the calling code's namespace, then the global one (§11.1), never
in the namespace that declares `x`'s type. So a library's functions on its own types
can't be called with UFCS from a program, which must name the namespace on each call.
Expected: UFCS tries the receiver type's namespace too, as the `format` hook does (§3.7).
Within the library itself, and for programs in the global namespace, nothing changes.

    // lib.goose
    namespace lib;
    import std;
    struct Cx { n: i64 }
    fn text(cx: const Cx&, s: const u8[:]) { print(s, " ", cx.n); }

    // main.goose
    import std;
    import .lib;
    fn main() { let cx = lib::Cx { n: 1 }; cx.text("ufcs"); }

    error: unknown function or member: text

goose-rest's every call takes the context first: `rest::text(cx, 200, "ok")`,
`rest::fail(cx, 404, "project_not_found")`, `rest::param_int(cx, "id")`. With the lookup,
they'd read `cx.text(200, "ok")`, `cx.fail(404, "project_not_found")`, and
`cx.param_int("id")`, which is what a reader of Actix or Axum expects.

Workaround: name the namespace, `rest::text(cx, ...)`.

### The regex module has no anchors, so JSON Schema's pattern can't be checked

Found on `a6249a4`, task 003. Status: open; still refused on `46356c2`

`regex::compile` refuses `^`, `$`, `\A` and `\z`, as `stdlib.md` documents. JSON
Schema's `pattern` is an ECMA-262 regex that matches anywhere in the string, so schemas
anchor it to mean the whole string, `"^#[0-9a-f]{6}$"`. Without anchors, neither form
can be checked: an unanchored search finds the pattern anywhere, and comparing the
first match's span with the string's is wrong under leftmost-first matching (`a|ab` on
`ab` matches `a`). Expected: `^` and `$`, or a full-match function.

    import std;
    import regex;

    fn main() {
        var err: u8[>..] = [];
        let re = regex::compile("^#[0-9a-f]{6}$", err);
        print(err);
    }

    regex: anchors are not supported at offset 0 in ^#[0-9a-f]{6}$

Workaround: none. The generator refuses `pattern` (docs/generator.md).
