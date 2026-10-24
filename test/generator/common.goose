// What the tests of plod gen share: documents to give it, and the
// error it must give, or the code it must write. The code it writes is
// tested by test/generated/ and by scripts/test.sh's golden files.
import std;
import http from "github.com/kaitk/goose-http@v0.5.10";
import plod from "../../";
import plod.gen.gen;

// A document whose components.schemas is schemas.
fn doc(schemas: const u8[:]) -> u8[>..] {
    str("""{"openapi": "3.1.0", "components": {"schemas": """, schemas, "}}")
}

// A document with paths, a schema A, and a security scheme s.
fn api(paths: const u8[:]) -> u8[>..] {
    str("""{"openapi": "3.1.0", "paths": """, paths,
        """, "components": {"schemas": {"A": {"type": "object", "properties": {}}, "N": {"type": "string"}}, "securitySchemes": {"s": {"type": "http"}}}}""")
}

// The error, without the section of docs/generator.md it ends with, which
// test/generator/sections.goose checks.
fn fails(text: const u8[:], want: const u8[:]) {
    var out: u8[>..] = [];
    let full = gen::generate(text, "api", "app", "api.json", out);
    let at = find(full, " (generator.md §");
    let err = if at >= 0 { full[..at] } else { full[..] };
    if err != want {
        print("want '", want, "'\ngot  '", err, "'\nfor ", text);
        assert(false);
    }
}

fn generated(text: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    let err = gen::generate(text, "api", "app", "api.json", out);
    if err.len > 0 { print(err, "\nfor ", text); assert(false); }
    return out;
}
