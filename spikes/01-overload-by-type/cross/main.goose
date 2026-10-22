import plod;
import app;

fn main() {
    var cx = plod::Cx { cookie: "ok", page: 3 };
    app::handle(cx);
}
