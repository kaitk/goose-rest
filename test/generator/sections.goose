// goose-rest gen's errors end with the section of docs/generator.md that
// covers what they refuse: The subset (§4), Names (§5), and What it refuses
// (§7.2), for anything under paths or security.
import std;
import http from "github.com/kaitk/goose-http@v0.4.3";
import rest from "../../";
import rest.gen.gen;
import common;

fn full(text: const u8[:]) -> u8[] {
    var out: u8[>..] = [];
    return gen::generate(text, "api", "app", "api.json", out);
}

fn main() {
    print(full(doc("""{"A": {"type": "object", "properties": {"c": {"type": "string", "pattern": "^#"}}}}""")));
    print(full(doc("""{"A": {"type": "object", "properties": {"r": {"type": "string"}}}}""")));
    print(full(api("""{"x": {}}""")));
    print(full(api("""{"/a": {"get": {"operationId": "a", "security": [{"t": []}]}}}""")));
}
