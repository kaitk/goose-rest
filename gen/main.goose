// goose-rest gen: writes Goose types, JSON readers, and JSON writers from the
// schemas of an OpenAPI 3.1 document (docs/generator.md).
//
//   goose-rest gen IN -o OUT [--namespace NAME]
//
// NAME defaults to api. On an error, OUT isn't written, and the error goes to
// standard error as "goose-rest: IN: <JSON pointer>: <message>".
import std;
import os;
import .gen;

fn usage() {
    write_stderr("usage: goose-rest gen IN -o OUT [--namespace NAME]\n");
    exit(2);
}

fn main() {
    let a = args();
    guard a.len >= 5 && a[1] == "gen" else { usage(); }
    var input: const u8[:] = "";
    var output: const u8[:] = "";
    var ns: const u8[:] = "api";
    var i = 2;
    while i < a.len {
        if a[i] == "-o" && i + 1 < a.len { output = a[i + 1]; i += 2; }
        else if a[i] == "--namespace" && i + 1 < a.len { ns = a[i + 1]; i += 2; }
        else if input.len == 0 && a[i].len > 0 && a[i][0] != '-' { input = a[i]; i++; }
        else { usage(); }
    }
    guard input.len > 0 && output.len > 0 else { usage(); }
    guard gen::is_ident(ns) else { write_stderr("goose-rest: the namespace must be a Goose identifier\n"); exit(2); }
    var text: u8[>..] = [];
    guard read_file(input, text) else { write_stderr(str("goose-rest: can't read ", input, "\n")); exit(1); }
    var slash = -1;
    for c, k in input { if c == '/' || c == '\\' { slash = k; } }
    var out: u8[>..] = [];
    let err = gen::generate(text, ns, input[slash + 1..], out);
    guard err.len == 0 else { write_stderr(str("goose-rest: ", input, ": ", err, "\n")); exit(1); }
    guard write_file(output, out) else { write_stderr(str("goose-rest: can't write ", output, "\n")); exit(1); }
}
