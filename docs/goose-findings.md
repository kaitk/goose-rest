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
