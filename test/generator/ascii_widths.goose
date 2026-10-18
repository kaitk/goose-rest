// A string with maxLength 20 is 80 bytes, since a code point takes up to 4; a
// format whose values are ASCII takes 20 (36 for a uuid's exact length).
import std;
import http from "github.com/kaitk/goose-http@746f9567b5a51ca725b7e7e55f86cce8da703a56";
import rest from "../../";
import rest.gen.gen;
import common;

fn main() {
    let cases = [["", "80"], ["date", "10"], ["date-time", "20"], ["uuid", "36"], ["email", "20"], ["ascii", "20"]];
    for c in cases {
        let format = if c[0].len > 0 { str(",\"format\":\"", c[0], "\"") } else { str("") };
        let max = if c[0] == "date" { "10" } else if c[0] == "uuid" { "36" } else { "20" };
        let out = generated(doc(str("""{"A":{"type":"object","properties":{"s":{"type":"string","maxLength":""", max, format, "}}}}")));
        let want = str("    s: u8[..", if c[0].len == 0 { "80" } else { max }, "],\n");
        if find(out, want) < 0 { print("no '", want, "' for format '", c[0], "'\n", out); assert(false); }
    }
    let ok = generated(doc("""{"A":{"type":"object","properties":{"s":{"type":"string","format":"ascii"}}}}"""));
    assert(find(ok, "    s: u8[],\n") >= 0);
    assert(find(ok, "if has_s && !rest::is_ascii(s) { json::fail(r, \"s: format\"); }") >= 0);
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "string", "format": "ascii", "enum": ["a"]}}}}"""),
        "#/components/schemas/A/properties/c/format: not supported beside enum");
    fails(doc("""{"A": {"type": "object", "properties": {"c": {"type": "string", "format": "ASCII"}}}}"""),
        "#/components/schemas/A/properties/c/format: only date, date-time, uuid, email and ascii are supported");
    fails(doc("""{"A": {"type": "string", "format": "ascii", "minLength": 5, "maxLength": 4}}"""),
        "#/components/schemas/A: minLength and maxLength leave no value between them");
    print("string widths by format: ok");
}
