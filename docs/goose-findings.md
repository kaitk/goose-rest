# Goose findings

Goose compiler and stdlib gaps found here, in the format of goose-http's
`docs/goose-findings.md`. Each names the Goose commit it was found on.
## A long-distance return can't carry a slice a caller passed in

Found on `a6249a4`, spike 03. Status: open

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

## Passing a function value on by name keeps every HOF around it out of line

Found on `a6249a4`, spike 04. Status: open

A HOF that passes its function value on by name, `run(F)`, is inlined nowhere on that
path: the HOF, the callee, any HOFs around them, and the function whose blocks they
take all stay C functions, each passing free variables as pointers, with an `if (gs_rf)`
check after the call. `inline fn` doesn't change it. Passing a block that calls the value,
`run() { F() }`, inlines all of them. §7.6 expects a function value passed as a static
argument to be inlined into its HOF. The stdlib's `exception::try` forwards its body by
name the same way.

    import std;

    struct Cx { status: i32 }

    fn mw<F>(cx: Cx&) {
        guard cx.status == 0 else { return; }
        F();
    }
    fn route<F>(cx: Cx&) { let r = run(F); cx.status = r; }   // 0 inlined
    // fn route<F>(cx: Cx&) { let r = run() { F() }; cx.status = r; }   // 5 inlined
    fn run<F>() -> i32 { F(); return 0; }

    fn handler(cx: Cx&, id: i64) {
        mw(cx) { route(cx) { if id == 3 { cx.status = 1; } }; };
    }

    fn main() {
        var cx = Cx { status: 0 };
        handler(cx, 3);
        handler(cx, 4);
        print(cx.status);
    }

Clang 21 at `-O2` inlined the five C functions anyway; gcc wasn't checked.

Workaround: wrap a forwarded function value in a block.

## A case-function call missing a variant doesn't name it

Found on `a6249a4`, spike 06. Status: open

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

## A block can't push a value whose call grows a parameter's array

Found on `a6249a4`, task 003. Status: open

Inside a block, `v.push(read(scratch))` is refused when `scratch` is a parameter of the
enclosing function and `read` grows it. The same push outside a block compiles, and so
does the block when `scratch` is a local of the function. `v` is a local declared while
`scratch` is live, so the two can't share a stack (§1.2), and the growth can't land
inside the element being built. Expected: the block compiles as the plain push does.

    import std;

    struct P { id: i64, name: u8[] }

    fn read(scratch: u8[>..]&) -> P { scratch.push('x'); return P { id: 1, name: "a" }; }

    fn each<F>(n: i64) { for i in n { F(); } }

    fn many(scratch: u8[>..]&) -> P[>..] {
        var v: P[>..] = [];
        each(2) { v.push(read(scratch)); };     // refused
        // v.push(read(scratch));               // compiles
        return v;
    }

    fn main() { var s: u8[>..] = []; let v = many(s); print(v.len); }

    error: cannot call read, which grows scratch: the element pushed into v is still
    under construction, and the growth would land inside it (§1.3)

Workaround: push through a named function that takes both arrays,
`fn push_one(v: P[>..]&, scratch: u8[>..]&) { v.push(read(scratch)); }`, called from
the block. Binding `let p = read(scratch)` first is refused too, since `p` isn't
fixed-size and isn't copied implicitly (§4.1). The generated array readers push each
element this way: `json::each_element` takes the element's reader as a block.

## The regex module has no anchors, so JSON Schema's pattern can't be checked

Found on `a6249a4`, task 003. Status: open

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

## A thread can't read a string-literal global, so json::format_number fails in a thread

Found on `a6249a4`, task 004. Status: open, reported as
[aardappel/goose#31](https://github.com/aardappel/goose/issues/31) (2026-10-13); still
fails on `0bdbd18`

A global initialized with a string literal, `let PAIRS = "0001";` or `const PAIRS =
"0001";`, is a slice of static data, and a function a `thread_fn` reaches can't read it:
the compiler refuses it as a global that holds references. §11.2 says the opposite:
"`const` globals with compile-time initializers are static data (§1.2), read-only and
therefore shared as they are." The stdlib's `json::format_number` reads such a global,
`DIGIT_PAIRS`, in `put_digits`, so no thread can write a JSON number with it, and every
goose-http server answers requests on threads. Expected: the literal global is shared,
as §11.2 says, or the stdlib declares its table flat.

    import std;

    let PAIRS = "0001";
    // let PAIRS: u8[4] = "0001";   // builds

    thread_fn worker(i: i64) { print(PAIRS[i]); }

    fn main() { thread_wait(thread_spawn(worker, 1)); }

    error: thread programs may access only flat globals (§11.2): PAIRS holds references
    (reached from thread_fn worker)

The same error comes from a `thread_fn` that calls `json::format_number(out, 0.5)`,
pointing at `stdlib/json.goose:144`.

Workaround: the generated writers call `rest::format_number` (`check.goose`), which
writes `null` for NaN and the infinities and std's text of the double otherwise. That
text reads back as the same double and is valid JSON, but isn't always the shortest
form `json::format_number` writes. Declaring the table as `let DIGIT_PAIRS: u8[200] =
"..."` would fix the stdlib.

## A loop's checking doesn't settle when a block rebinds a reference that's stored

Found on `a6249a4`, task 008. Status: open, reported as
[aardappel/goose#32](https://github.com/aardappel/goose/issues/32) (2026-10-13); still
fails on `0bdbd18`

A loop that rebinds an optional reference with `.=` inside a block, then stores what it
leads to, fails to check when the function holding the loop runs from another block:
"this loop's checking does not settle (internal limit of 16 passes)". The error points
at `json::each`'s own loop, not at the program's. Each of these makes it compile: rebind
outside the block (`chosen .= json::member(list, "a")`), store something else, or call
`load(root)` directly instead of from `json::each`. Expected: the program compiles, or
an error names the rule it breaks.

    import std;
    import json;

    struct P { name: const u8[:], n: i64 }

    fn run(text: const u8[:]) -> i64 {
        var doc: json::Node[>..] = [];
        var decoded: u8[>..] = [];
        var ps: P[>..] = [];

        fn load(list: json::Node&) {
            for i in 2 {
                var chosen: json::Node? = null;
                json::each(list) { p => if p.key == "a" { chosen .= p; } };
                guard chosen else { continue; }
                ps.push(P { name: chosen.key, n: i });
            }
        }

        let root, err = json::parse(text, doc, decoded);
        guard root else { return -1; }
        json::each(root) { item => load(item); };
        return ps.len;
    }

    fn main() { print(run("""{"x": {"a": 1, "b": 2}, "y": {"a": 3}}""")); }

    stdlib/json.goose:746: error: this loop's checking does not settle (internal limit
    of 16 passes)
        while c {
      in fn json::each<F = {block at h.goose:22:22}>(json::Node&) instantiated from h.goose:22

Workaround: find the index inside the block and fetch the node after it, as the
generator's `index_of_name` and `nth` do (`gen/gen.goose`).

## A block given a local struct gets a copy of it

Found on `a6249a4`, task 005. Status: open, recorded in goose-http's findings ("A block
given a local struct writes to a copy of it", found on `5c83a5a`)

`rest::json_body` hands its block a `json::Reader` it declared, `R(r, cx.scratch)`, and
the block's reader advanced a copy: `json::finish` then found the whole body unread and
reported "trailing input" at byte 0. Expected: the block's parameter binds the local
itself, as an untyped function parameter does.

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

## A function called once isn't inlined past a size

Found on `a6249a4`, task 006. Status: open, reported as
[aardappel/goose#33](https://github.com/aardappel/goose/issues/33) (2026-10-13); still
fails on `0bdbd18`

A function with one call site stays a call once its body passes a size, at `-O1` and
`-O2`, though `docs/implementation.md` says the inliner inlines "if K is used once, or
its post-optimization node count is below NC, ...". With 15 of the statements below,
`handle` is inlined into `main`; with 16, the C keeps `handle_g` and calls it. Nothing
nests deeper than one `if`, so it isn't the nesting limit. Called from inside a loop,
whose size allowance is four times larger, it's inlined again. Expected: a callee used
once is inlined whatever its size, as the notes say, or the notes state the limit.

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

## A second u8[>..] global makes a push through a struct's array field fail to check

Found on `0bdbd18`, task 010. Status: open, reported as
[aardappel/goose#34](https://github.com/aardappel/goose/issues/34) (2026-10-13)

Whether a push of a value whose call grows another array checks depends on how many
`u8[>..]` globals the program declares: with none or two it's refused, with one it
compiles. `v` and `scratch` have different element types, so §5.1's "any array of its
type" can't make them one array, and growth through `scratch` can't land inside `v`'s
element. The stdlib's `os.goose` declares one such global, `argv_text`, so a program
that imports `os` or goose-http compiles until it declares a `u8[>..]` global of its own,
`reusable[]` or not. goose-rest's generated array readers push this way, from a block
given a `Cx`, with `cx.scratch`. Expected: the push checks whatever globals exist.

    import std;

    struct Cx { scratch: u8[>..]& }

    fn mk(scratch: u8[>..]&) -> u8[] { scratch.push('a'); return "x"; }

    fn push_one(v: u8[][>..]&, scratch: u8[>..]&) { v.push(mk(scratch)); }

    fn with_cx<H>() {
        var scratch: u8[>..] = [];
        var cx = Cx { scratch: scratch };
        H(cx);
    }

    var first: u8[>..] = [];
    var spill: u8[>..] = [];      // delete this line and it checks and runs

    fn main() {
        with_cx() { cx =>
            var v: u8[][>..] = [];
            push_one(v, cx.scratch);
            print(v.len);
        };
    }

    error: cannot call mk, which grows scratch: the element pushed into v is still
    under construction, and the growth would land inside it (§1.3)

It needs a pushed element that isn't fixed-size, a callee that grows `scratch`, the push
in a function whose `v` is a parameter, and `scratch` read from a struct's reference
field in a block. Pushing into a local `v` in the block checks.

Workaround: `rest::serve` keeps its body spill as a `reusable[]` local, passed down as
a pool reference, not as a global.
