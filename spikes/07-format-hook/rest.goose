namespace rest;

import std;

struct Cx { status: i32, body: u8[>..] }

// rest's own format overload: the error body. It doesn't hide the
// application's overloads from json.
struct Failure { code: u8[..32] }

fn format(out: u8[>..]&, f: const Failure&) {
    out.append("{\"error\":\"");
    out.append(f.code);
    out.append("\"}");
}

// Writes v as the JSON body, through the format overload of v's type, found
// in the namespace that declares the type (spec §3.7).
fn json(cx: Cx&, status: i32, v) {
    cx.status = status;
    cx.body.clear();
    format(cx.body, v);
}

fn fail(cx: Cx&, status: i32, code: const u8[:]) {
    var f = Failure { code: [] };
    f.code.append(code);
    json(cx, status, f);
}
