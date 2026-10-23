// The entry without TLS (app.goose), for the profiles on 8080 and 8082.
import std;
import http from "github.com/kaitk/goose-http@v0.5.5";
import compress from "github.com/kaitk/goose-compress@v0.1.1";
import hash from "github.com/kaitk/goose-hash@v0.0.4";
import pg from "github.com/kaitk/goose-postgres@v0.0.3";
import plod from "../../../";
import app;

thread_fn worker(cfg: http::Config) {
    var app = App { db: pg::pool(db_cfg, per_worker) };
    let e = plod::serve(cfg, app, St { .. }) { cx => on_call(cx); };
    pg::close(app.db);
    if e.code != 0 { http::report(e); }
}

fn main() {
    http::exit_on_error(http::stop_on_signals());
    load_dataset();
    let cfg = config();
    load_database(cfg);
    http::run(cfg, worker);
}
