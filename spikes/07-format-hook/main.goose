// Spike 07: does rest::json, generic and in namespace rest, find the format
// overload declared in the value's namespace, for a nested type too? See
// README.md.
import std;
import rest;
import app;

fn main() {
    for n in 5 {
        var cx = rest::Cx { status: 0, body: [] };
        app::handle(cx, n);
        print(cx.status, " ", cx.body);
    }
}
