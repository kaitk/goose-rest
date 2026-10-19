// Property names goose-rest gen renames rather than refuses: a Goose
// keyword, and a name in capitals.
import std;
import http from "github.com/kaitk/goose-http@ff18ecc766651a4ff0143361413c81f33873c8b2";
import rest from "../../";
import rest.gen.gen;
import common;

fn main() {
    var out: u8[>..] = [];
    let err = gen::generate(doc("""{"A": {"type": "object", "properties": {"type": {"type": "string"}, "HTTPServer": {"type": "boolean"}}}}"""),
        "api", "app", "api.json", out);
    if err.len > 0 { print(err); assert(false); }
    assert(find(out, "    has_type_: bool,\n    type_: u8[],\n") >= 0);
    assert(find(out, "    http_server: bool,\n") >= 0);
    print("names renamed: ok");
}
