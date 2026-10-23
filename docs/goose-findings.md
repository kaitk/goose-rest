# Goose findings

Goose compiler and stdlib gaps found here, in the format of goose-http's
`docs/goose-findings.md`. Each entry names the Goose commit the gap was found on, and the one it
was last checked on. A gap fixed upstream leaves this file with the pin move that
takes the fix.

The entries come in two parts: [bugs](#bugs), where Goose does something wrong or other
than its spec says, then [feature requests](#feature-requests), for what it lacks. Each
part runs from the least work a fix is expected to take to the most, so the cheap fixes
come first. The order is an estimate from reading the compiler. Place a new entry where
its expected work puts it.

## Bugs

### A case-function call missing a variant doesn't name it

Found on `a6249a4`, spike 06. Status: open; unchanged on `dcc2747`

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

The same holds where a variant's case exists but another of its parameters doesn't fit
(spike 10's `lane_types.goose`, found on `dcc2747`): with `run(u: Use.Report, r:
Reader&)` and a call `run(u, w)` for a `Writer`, every candidate says `argument 1:
cannot pass Use as Use.Report`, and none says that argument 2 is the mismatch.
Expected: the variant that has no case for these arguments, as above.

Workaround: none needed; compare the candidates with the enum's variants.

### A package's module can't import another module of its package

Found on `3ee3871` (release `v2026.2`), the benchmark server. Status: open

Spec §11.1 resolves `import pkg.mod;` among the root's declared packages, as
`docs/design/packages.md` §4.4 lists it. From a module inside a package the root imports,
the same import looks only under that module's package directory (`<package>/pkg/`) and in
the stdlib, so it fails. The same import written in the root resolves. goose-http's
`bench/rest/goose/app.goose`, which the benchmark server imports, can't import
`http.store` for this reason.

    // app/main.goose
    import mylib2 from "../mylib2";
    import mylib2.sub.user;
    fn main() { print(used()); }

    // mylib2/mylib2.goose
    fn entry() -> i64 { 1 }

    // mylib2/extra.goose
    fn helper() -> i64 { 2 }

    // mylib2/sub/user.goose
    import mylib2.extra;
    fn used() -> i64 { helper() }

    $ goose run app/main.goose
    mylib2/sub/user.goose:1: error: cannot find the module mylib2.extra, looked for
        .../mylib2/mylib2/extra.goose
        .../stdlib/mylib2/extra.goose

Expected: `2`. Importing `mylib2.extra` in `app/main.goose` as well doesn't help while
`user.goose` keeps its import.

Workaround: the module leaves the import out and the root imports the module instead:
`bench/rest/plod/main.goose` imports `http.store` for `app.goose`.

### A block given a local struct gets a copy of it

Found on `a6249a4`. Status: open; still prints 0 on `46356c2`. Recorded in
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

Plod meets it with a context that holds the router a route's block adds: `rest::scope`
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

### A mismatch names the type variable, not the type another argument bound it to

Found on `dcc2747`, spike 11. Status: open

A call whose argument doesn't fit a type variable that an earlier argument bound says
it can't pass the argument "as U", and not as the type `U` stands for at that call.
Expected: the bound type, and the argument that bound it, as in "cannot pass
Reports.Totals as U (Writes, from argument 1)".

    import std;
    enum Writes { Create { project: i64 } }
    enum Reports { Totals { project: i64 } }
    struct Lane<U> { n: i64 }
    fn ask<U>(lane: const Lane<U>&, job: U) {}
    fn main() {
        let writer = Lane<Writes> { n: 1 };
        ask(writer, Writes.Create { project: 3 });
        ask(writer, Reports.Totals { project: 4 });
    }

    error: no matching overload for call to ask
      candidate ask at bound.goose:5: argument 2: cannot pass Reports.Totals as U

Plod meets it when a route sends a job to the wrong lane (spike 11): the error
names the job but not the lane's enum it should be a variant of.

Workaround: read the lane's type at the call: `cx.app.writer` is a
`rest::Lane<Writes, Use>`.

### A call written `x.f()` can't take type arguments

Found on `ac759c3` (`v2026.1`). Status: open

`x.f<T>()` doesn't parse, so a generic function whose type parameter isn't inferred
from its arguments is called only as `f<T>(x)`. Expected: explicit type arguments in a
call written with a receiver, as Rust's `iter.collect::<Vec<_>>()` has.

    import std;
    struct Query { sql: u8[..64] = "" }
    struct Project { id: i64 = 7 }
    fn fetch_one<T>(q: Query) -> T { return default<T>(); }
    fn main() {
        let q = Query { sql: "SELECT 1" };
        print(q.fetch_one<Project>().id);
    }

    error: expression expected, found ')'

The same call written `x.f()` also finds `f` only in the calling code's namespace (spec
§11.1), so `db::query(sql).bind(owner)` from outside `db` is "unknown function or
member: bind". Together they keep a library's calls from chaining as a Rust driver's do:
the tutorial's fake database reads as plain calls,
`db::fetch_one<db::Project>(c, sql, [id])`.

Workaround: plain calls.

### A function can't return a valueless call

Found on `46356c2`. Status: open

`return f();` is refused when `f` returns nothing, so a function that ends on such a
call writes it and then `return;`. Expected: `return` of a valueless expression in a
function without a result, as C++ and Rust allow, so a branch that hands off can end in
one statement.

    import std;
    fn wrap<F>() { F(); }
    fn f() { return wrap() { print("in"); }; }
    fn main() { f(); }

    error: cannot return a valueless expression

Plod's plan wrote each generated route as `return rest::route(cx) { ... };`.

Workaround: `rest::route(cx) { ... };` and then `return;`, as the generated router does.

### An error inside a generic function lists every frame up to main

Found on `46356c2`. Status: open

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

Plod meets it when a handler the schema names is missing: the generated
`dispatch` is generic in `cx` and `state`, and runs inside `rest::serve`'s block, which
runs inside goose-http's event loop, so the error lists 18 frames, 8 of them in
goose-http's loop (`http::answer`, `http::pump`, `http::mail_take`, and so on). The
generated code can't shorten it: a named function that calls the handler would be
generic in `cx` too, and get the same chain.

Workaround: read the first lines. The error's line in `api_gen.goose` names the call,
and the first frames name the operation ([tutorial](tutorial/05-schema.md#when-the-schema-and-the-handlers-disagree)).

### An overload that takes the whole enum hides its case functions without a word

Found on `dcc2747`, spike 10; checked with one enum per lane in spike 11. Status: open

A call with an enum value takes an overload whose parameter is the enum, or untyped,
before it tries tag dispatch (§7.1: "Only if no ordinary candidate matches is tag
dispatch tried"), so a catch-all beside a complete set of case functions takes every
call, and the cases never run. That is the spec's order, but nothing says so, and a
library that dispatches a program's enum can't check it: Goose has no way to require
that a call dispatch. Expected: a warning where an overload hides case functions that
cover every variant, or a form of call that only dispatches.

    import std;
    enum Writes { Create { project: i64 }, Close { id: i64 } }
    fn run(u) {}
    fn run(u: Writes.Create) { print("create ", u.project); }
    fn run(u: Writes.Close) { print("close ", u.id); }
    fn main() {
        let u: Writes = Writes.Create { project: 3 };
        run(u);   // prints nothing, without a warning
    }

Plod's lanes dispatch each job to the program's `run` cases, and each reply to
the program's `resume` cases. A catch-all `run` drops every job, and the route waits
for a reply that never comes; a catch-all `resume` answers every reply alike.

Workaround: `rest::lane` answers 500 `no_reply` for a job whose `run` returned without
replying (spike 11, in `waiting.goose` since 2026-10-19), and the reference and best
practices warn against a catch-all. A catch-all that replies, or any catch-all
`resume`, still goes unnoticed.

### Goose code has no target-platform constant

Found and checked on `f114b5ac52cfad4bc73038aede53ac7e470b0ad3`, the pin in
`scripts/goose.sh` (2026-10-20). Status: open

Neither the builtins nor `stdlib/os.goose` exposes a target OS at compile time.
The benchmark server calls glibc's `mallopt` during startup, so this reduced program
links on glibc Linux and fails on macOS:

    extern fn mallopt(param: i32, value: i32) -> i32;
    fn main() { mallopt(-3, 131072); }

    Undefined symbols for architecture arm64:
      "_mallopt", referenced from: _main

Expected: a compile-time target value that lets the compiler omit a foreign call on
a platform without that symbol. A runtime check leaves the symbol to link.

`docs/packages.md` §3 offers platform-specific `.build` entries such as
`c_sources_linux` and `c_defines_macos`, and `-D` defines C macros. These select C
build inputs, not Goose source. Checked against `src/builtins.h`,
`stdlib/os.goose`, `src/packages.h`, and the specification.

Workaround: none within a change limited to the benchmark's `main.goose`, with no C
and identical Linux output. The macOS instruction-count run remains blocked.

### A function called once isn't inlined past a size

Found on `a6249a4`. Status: open, reported as
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

Plod meets it in a handler behind middleware: a block-taking function such as
`rest::cors`, given the handler's routes as its block, passes the size at once. It then
stays a call that reaches the handler's locals through pointers, and the handler stays
a call around it. `inline fn` makes each one inline.

Workaround: Plod's functions that take a block are `inline fn` (`route`,
`attempt`, `cors`, `bearer`, `timed`, `json_body`), so the middleware, the route, and
the code that fails all fold into the handler, which may stay one function of its own
(`test/inline_route.goose`).

### A function called once can't be kept out of line

Found on `ac759c3` (`v2026.1`). Status: open

The inverse of the entry above. A function with one call site is inlined unless its
body passes the size limit that entry names, four times larger in a loop, or the call is
in a guard's `else` or an arm that ends in a `return`, `break`, or `abort`
(implementation notes, "Inlining"); and the C compiler inlines a static function with
one caller unless Goose declares it `GS_NOINLINE`. A call that is rare but within the
limit and not on such an arm can't be kept out of line. Expected: a way to ask for it, as
Rust's `#[inline(never)]` or C's `noinline`. Below, `rare` is inlined into `main`'s
loop at `-O2`, and the C has `main_g` alone:

    import std;
    import os;

    fn rare(buf: u8[>..]&, id: i64) {
        if id == 0 { buf.append(str("v", id, "0")); }
        // ... the same for 1 to 15
        if id == 16 { buf.append(str("v", id, "16")); }
    }

    fn main() {
        var b: u8[>..] = [];
        for i in args().len {
            b.push('.');
            if i > 100 { rare(b, i); }
        }
        print(b);
    }

Plod meets it in `rest::serve`: the calls after a request's first, for bodies and
responses in pieces, go through one function, `on_later`, so that the program's handler
has one copy there. goose-http's loop calls `serve`'s block once in each of its places,
and Goose inlines `on_later` into each, the request path's included. A `while` with a
`break` around the call isn't taken as cold either.

Workaround: none. The request path holds the handler twice, as it did before `on_later`,
when the second copy was the one for a gathered body.

### A block that ends in a return keeps its calls out of line

Found on `f114b5a`, spike 12. Status: open

The arm rule of the entry above also applies to a block given to an `inline fn`. A
function value called in an arm that ends in a `return` is treated as cold, and a
function called once inside it stays a call at half the usual size: 8 statements
instead of 16. Expected: the arm's own statements counted as cold, not the body of a
block it runs, or a way to ask for the block's calls to be inlined. Below, the C keeps
`twice_g`. With 7 statements, or with `if c { F(); } if c { return; }`, it has `main_g`
alone:

    import std;
    import os;

    fn twice(buf: u8[>..]&, n: i64) {
        if n == 1 { buf.append(str("v", n, "1")); }
        // ... the same for 2 to 7
        if n == 8 { buf.append(str("v", n, "8")); }
    }

    inline fn when<F>(c: bool) {
        if c {
            F();
            return;
        }
    }

    fn main() {
        let n = args().len;
        when(n > 1) { var b: u8[>..] = []; twice(b, n); print(b); };
        print("end");
    }

Plod meets it in spike 12's `compact::on`, which runs a route's block and then
leaves `routes` with `return from routes`. `rest::param_int` in the block stays a call.
It's a function that fails, so its route and everything around the route stay out of
line too.

Workaround: the block and the `return` in separate arms, `if hit { F(); }` and then
`if hit { return from routes; }`.

### Every temporary of a function takes its own stack slot

Found on `ac759c3` (`v2026.1`). Status: open

The C that Goose writes declares a function's temporaries at the top of the C function,
those of every body inlined into it included, so the C compiler can't give two of them,
used in different branches, one stack slot. A struct passed by value to a call that
stays out of line gets a temporary of its own at each call, so the frame grows with the
calls in the function, not with the deepest branch. With gcc's
`-fstack-clash-protection`, Ubuntu's default, a frame of more than a page is probed a
page at a time on every call, whichever branch runs. Expected: a temporary declared in
the C block of the statement that uses it, or slots shared between branches. Below,
`main`'s 64 calls in 64 branches give the C 129 `Big` temporaries of 64 bytes each, and
gcc `-O2` an 8 KB frame that it probes twice per call:

    import std;
    import os;

    struct Big { a: i64, b: i64, c: i64, d: i64, e: i64, f: i64, g: i64, h: i64 }

    // Too big to inline: a call that takes x by value.
    fn show(x: Big, k: i64) -> i64 {
        var s = 0;
        for i in x.a { s += i * x.h + k; if s > 1000 { print(s); } }
        for i in x.b { s += i * x.g; if s > 2000 { print(s); } }
        for i in x.c { s += i * x.f; if s > 3000 { print(s); } }
        return s;
    }

    inline fn twice<F>() -> i64 { F() + F() }

    fn main() {
        let x = Big { a: args().len, b: 0, c: 0, d: 0, e: 0, f: 0, g: 0, h: 1 };
        let n = args().len;
        var t = 0;
        if n == 0 { t += twice() { show(x, 0) }; }
        // ... the same for 1 to 62
        if n == 63 { t += twice() { show(x, 63) }; }
        print(t);
    }

Plod meets it in a router. `rest::route` is an `inline fn`, and `rest::Cx`, about
170 bytes, goes by value to each call in a route, so a function that holds many routes
holds about 1 KB of frame for each. The generated router for the 203 routes of tier R
had a frame of 217 KB, and its probes took 56% of the server's user cycles per request;
built with `-fno-stack-clash-protection`, a request took 923 cycles instead of 2,220.

Workaround: the generator writes each operation as a function of its own, called from an
arm that returns, which Goose keeps out of line (`gen/router.goose`). A hand-written
chain of many routes in one function still pays it: tier R's has a frame of 190 KB.

### UFCS doesn't reach the namespace of the receiver's type

Found on `46356c2`. Status: open

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

Every Plod call takes the context first: `rest::text(cx, 200, "ok")`,
`rest::fail(cx, 404, "project_not_found")`, `rest::param_int(cx, "id")`. With the lookup,
they'd read `cx.text(200, "ok")`, `cx.fail(404, "project_not_found")`, and
`cx.param_int("id")`, which is what a reader of Actix or Axum expects. A test that
plays a lane writes `rest::wake(p)` for the `rest::Played` it got, where `p.wake()`
fails the same way. goose-http's HTTP client reads
`http::post(session, url) { req => http::bearer(req, key); }` where
`session.post(url) { req => req.bearer(key); }` is meant; still so on `v2026.3`
(2026-10-22).

Workaround: name the namespace, `rest::text(cx, ...)`.

### The regex module has no anchors, so JSON Schema's pattern can't be checked

Found on `a6249a4`. Status: open; still refused on `46356c2`

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
