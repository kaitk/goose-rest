// error: unknown function: from_request
// rest::take of a type no from_request reads. The generator writes one for
// each schema object in its subset, and refuses a schema outside it, such as
// a oneOf of shapes, so a type standing for that schema has none.
import std;
import http from "github.com/kaitk/goose-http@v0.5.3";
import rest from "../../";

struct Shape { kind: u8[], radius: f64 }

fn main() {
    let out = rest::serve_one("POST / HTTP/1.1\r\n\r\n") { cx =>
        let s = rest::take<Shape>(cx);
        rest::text(cx, 200, str(s.radius));
    };
    print(out);
}
