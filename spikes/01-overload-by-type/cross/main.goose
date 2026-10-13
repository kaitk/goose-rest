import rest;
import app;

fn main() {
    var cx = rest::Cx { cookie: "ok", page: 3 };
    app::handle(cx);
}
