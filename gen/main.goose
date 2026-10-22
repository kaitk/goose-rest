// plod gen: writes Goose types, JSON readers, and JSON writers from the
// schemas of an OpenAPI 3.1 document, and a router from its paths
// (docs/generator.md).
//
//   plod gen IN -o OUT [--namespace NAME] [--handlers NAME]
//
// The namespace defaults to api, and the handlers' to app. On an error, OUT
// isn't written, and the error goes to standard error as "plod: IN:
// <JSON pointer>: <message>".
import std;
import os;
import .gen;

fn usage() {
    write_stderr("usage: plod gen IN -o OUT [--namespace NAME] [--handlers NAME]\n");
    exit(2);
}

fn main() {
    let a = args();
    guard a.len >= 5 && a[1] == "gen" else { usage(); }
    var input: const u8[:] = "";
    var output: const u8[:] = "";
    var ns: const u8[:] = "api";
    var handlers: const u8[:] = "app";
    var i = 2;
    while i < a.len {
        if a[i] == "-o" && i + 1 < a.len { output = a[i + 1]; i += 2; }
        else if a[i] == "--namespace" && i + 1 < a.len { ns = a[i + 1]; i += 2; }
        else if a[i] == "--handlers" && i + 1 < a.len { handlers = a[i + 1]; i += 2; }
        else if input.len == 0 && a[i].len > 0 && a[i][0] != '-' { input = a[i]; i++; }
        else { usage(); }
    }
    guard input.len > 0 && output.len > 0 else { usage(); }
    guard gen::is_ident(ns) && gen::is_ident(handlers) else {
        write_stderr("plod: a namespace must be a Goose identifier\n");
        exit(2);
    }
    var text: u8[>..] = [];
    guard read_file(input, text) else { write_stderr(str("plod: can't read ", input, "\n")); exit(1); }
    var slash = -1;
    for c, k in input { if c == '/' || c == '\\' { slash = k; } }
    var out: u8[>..] = [];
    let err = gen::generate(text, ns, handlers, input[slash + 1..], out);
    guard err.len == 0 else { write_stderr(str("plod: ", input, ": ", err, "\n")); exit(1); }
    guard write_file(output, out) else { write_stderr(str("plod: can't write ", output, "\n")); exit(1); }
}
