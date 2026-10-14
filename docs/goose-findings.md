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
