// error: unknown function: from_request
// rest::take of a type no from_request reads. The generator writes one for
// each schema object in its subset, and refuses a schema outside it, such as
// a oneOf of shapes, so a type standing for that schema has none.
import std;
import http from "github.com/kaitk/goose-http@746f9567b5a51ca725b7e7e55f86cce8da703a56";
import rest from "../../";

struct Shape { kind: u8[], radius: f64 }

fn main() {
    let out = rest::serve_one("POST / HTTP/1.1\r\n\r\n") { cx =>
        let s = rest::take<Shape>(cx);
        rest::text(cx, 200, str(s.radius));
    };
    print(out);
}
