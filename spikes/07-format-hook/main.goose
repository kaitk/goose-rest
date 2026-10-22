// Spike 07: does plod::json, generic and in namespace plod, find the format
// overload declared in the value's namespace, for a nested type too? See
// README.md.
import std;
import plod;
import app;

fn main() {
    for n in 5 {
        var cx = plod::Cx { status: 0, body: [] };
        app::handle(cx, n);
        print(cx.status, " ", cx.body);
    }
}
