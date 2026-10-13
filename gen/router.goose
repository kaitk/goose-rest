// Writes dispatch, the router, from load's tables. A path without '%' is
// looked up among the static paths by length, then bytes. Then every path is
// matched segment by segment, as a trie: at each segment the literals first,
// in the document's order, then a parameter, so that a concrete path wins
// over a template, and a branch that doesn't answer falls through to the
// next. docs/generator.md shows the code.
namespace gen;

import std;

let SPACES = "                                                                                                    ";

fn indent(level: i64) -> const u8[:] { SPACES[..min(4 * level, SPACES.len)] }

// What the router's emitters read, and where they write.
struct Tables {
    out: u8[>..]&,
    handlers: const u8[:],
    routes: const Route[:],
    segs: const Seg[:],
    ops: const Op[:],
    params: const PathParam[:],
    objs: const Obj[:],
}

// The statements, at level, that answer a request whose path matched r:
// each operation in the path item's order, then OPTIONS' 204 or a 405, with
// r's Allow. Each answer returns.
fn emit_ops(t: Tables&, r: Route, level: i64) {
    let ind = indent(level);
    let in2 = indent(level + 2);
    for o in t.ops[r.first_op..r.first_op + r.nops] {
        if o.method == "GET" { format(t.out, ind, "if m == \"GET\" || m == \"HEAD\" {\n"); }
        else { format(t.out, ind, "if m == \"", o.method, "\" {\n"); }
        format(t.out, ind, "    rest::route(cx) {\n");
        if o.scheme.len > 0 { format(t.out, in2, "let s_ = ", t.handlers, "::", o.scheme, "(cx, state);\n"); }
        var k = 0;
        for s, i in t.segs[r.first_seg..r.first_seg + r.nsegs] {
            if !s.param { continue; }
            let p = t.params[o.first + k];
            k++;
            if !p.int {
                format(t.out, in2, "let ", p.local, " = s", i + 1, ";\n");
                continue;
            }
            format(t.out, in2, "let ", p.local, " = rest::path_int(cx, s", i + 1, ", \"", p.name, "\");\n");
            if p.int32 {
                format(t.out, in2, "if ", p.local, " < -2147483648 || ", p.local, " > 2147483647 { rest::fail_param(cx, \"",
                       p.name, ": format\"); }\n");
            }
            if p.has_minimum {
                format(t.out, in2, "if ", p.local, " < ", p.minimum, " { rest::fail_param(cx, \"", p.name, ": minimum\"); }\n");
            }
            if p.has_maximum {
                format(t.out, in2, "if ", p.local, " > ", p.maximum, " { rest::fail_param(cx, \"", p.name, ": maximum\"); }\n");
            }
        }
        if o.body >= 0 {
            format(t.out, in2, "guard http::has_type(cx.req, \"application/json\") else { rest::fail(cx, 415, \"unsupported_media_type\"); }\n");
            format(t.out, in2, "var r_ = json::reader(cx.body);\n");
            format(t.out, in2, "var scratch_: u8[>..] = [];\n");
            format(t.out, in2, "let body_ = read_");
            format_snake_name(t.out, t.objs[o.body].name);
            t.out.append("(r_, scratch_);\n");
            format(t.out, in2, "if !json::finish(r_) { rest::fail_body(cx, r_); }\n");
        }
        format(t.out, in2, t.handlers, "::", o.handler, "(cx, state");
        if o.scheme.len > 0 { t.out.append(", s_"); }
        for p in t.params[o.first..o.first + o.count] { format(t.out, ", ", p.local); }
        if o.body >= 0 { t.out.append(", body_"); }
        t.out.append(");\n");
        format(t.out, ind, "    };\n", ind, "    return;\n", ind, "}\n");
    }
    format(t.out, ind, "rest::no_method(cx, \"", r.allow, "\");\n", ind, "return;\n");
}

// The trie's node for the routes idx[lo..hi], whose first d segments all
// match the path's, at level: the route that ends there, then the segment
// after, each literal and then a parameter, each with the routes that go on
// through it. idx is a stack of route indices, each node's above its
// parent's.
recursive fn emit_node(t: Tables&, idx: i64[>..<]&, lo: i64, hi: i64, d: i64, level: i64) {
    let ind = indent(level);
    var deeper = false;
    for k in lo..hi {
        let r = t.routes[idx[k]];
        if r.nsegs == d {
            format(t.out, ind, "if e", d, " == path.len {\n");
            emit_ops(t, r, level + 1);
            format(t.out, ind, "}\n");
        } else {
            deeper = true;
        }
    }
    guard deeper else { return; }
    format(t.out, ind, "if e", d, " < path.len {\n");
    format(t.out, ind, "    let s", d + 1, ", e", d + 1, " = rest::segment(path, e", d, ");\n");
    for k in lo..hi {
        let r = t.routes[idx[k]];
        if r.nsegs <= d || t.segs[r.first_seg + d].param { continue; }
        let lit = t.segs[r.first_seg + d].text;
        var first = true;
        for j in lo..k {
            let q = t.routes[idx[j]];
            if q.nsegs > d && !t.segs[q.first_seg + d].param && t.segs[q.first_seg + d].text == lit { first = false; }
        }
        if !first { continue; }
        let mark = idx.len;
        for j in k..hi {
            let q = t.routes[idx[j]];
            if q.nsegs > d && !t.segs[q.first_seg + d].param && t.segs[q.first_seg + d].text == lit { idx.push(idx[j]); }
        }
        format(t.out, ind, "    if rest::segment_is(s", d + 1, ", \"", lit, "\", plain) {\n");
        emit_node(t, idx, mark, idx.len, d + 1, level + 2);
        format(t.out, ind, "    }\n");
        idx.resize(mark);
    }
    let mark = idx.len;
    for k in lo..hi {
        let r = t.routes[idx[k]];
        if r.nsegs > d && t.segs[r.first_seg + d].param { idx.push(idx[k]); }
    }
    if idx.len > mark {
        format(t.out, ind, "    if s", d + 1, ".len > 0 {\n");
        emit_node(t, idx, mark, idx.len, d + 1, level + 2);
        format(t.out, ind, "    }\n");
    }
    idx.resize(mark);
    format(t.out, ind, "}\n");
}

// Writes dispatch, which calls the handlers in the namespace handlers.
fn emit_router(out: u8[>..]&, handlers: const u8[:], routes: const Route[:], segs: const Seg[:], ops: const Op[:],
               params: const PathParam[:], objs: const Obj[:]) {
    var t = Tables { out: out, handlers: handlers, routes: routes, segs: segs, ops: ops, params: params, objs: objs };
    format(out, "\n// Answers a request through the handler in ", handlers, " that its path and method\n");
    out.append("// name, inside rest::route; with 405 or OPTIONS' 204 and Allow for another method of\n");
    out.append("// a path; and as rest::otherwise does for a path no route takes.\n");
    out.append("fn dispatch(cx, state) {\n");
    out.append("    let path = http::path_of(cx.req.target);\n");
    out.append("    let m = cx.req.method;\n");
    out.append("    guard http::known_method(m) && http::is_routable(path) else { rest::no_route(cx, m, path); return; }\n");
    out.append("    let plain = find(path, \"%\") < 0;\n");
    var lens: i64[>..] = [];
    for r in routes { if r.is_static && !lens.contains(r.template.len) { lens.push(r.template.len); } }
    sort(lens) { a, b => a < b };
    if lens.len > 0 {
        out.append("    if plain {\n");
        out.append("        match path.len {\n");
        for n in lens {
            format(out, "            ", n, " => {\n");
            for r in routes {
                if !r.is_static || r.template.len != n { continue; }
                format(out, "                if path == \"", r.template, "\" {\n");
                emit_ops(t, r, 5);
                out.append("                }\n");
            }
            out.append("            },\n");
        }
        out.append("            _ => {},\n");
        out.append("        }\n");
        out.append("    }\n");
    }
    out.append("    if path.len > 0 && path[0] == '/' {\n");
    out.append("        let e0 = 0;\n");
    var idx: i64[>..<] = [];
    for i in routes.len { idx.push(i); }
    emit_node(t, idx, 0, routes.len, 0, 2);
    out.append("    }\n");
    out.append("    rest::not_found(cx, m, path);\n");
    out.append("}\n");
}
