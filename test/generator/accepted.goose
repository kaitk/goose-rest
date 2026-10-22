// Property names goose-rest gen renames rather than refuses: a Goose
// keyword, and a name in capitals.
import std;
import http from "github.com/kaitk/goose-http@b5f82a2d302b01c83e6d5073641720238590af22";
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
