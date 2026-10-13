// Spike 06's handler served by goose-http's loop, for curl: one worker and
// the database thread, on port 8080. Ctrl+C stops it.
import std;
import http from "github.com/kaitk/goose-http@e27ab215c8101a231a375cdfada182d3c9b388d7";
import app;

thread_fn worker(cfg: http::Config) {
    let e = http::serve(cfg, app::St { .. }, app::handle);
    if e.code != 0 { http::report(e); }
}

fn main() {
    let cfg = http::Config { port: 8080, workers: 1, mail_slots: app::SLOTS, mail_size: app::SLOT_SIZE,
                             max_waiting: 64, .. };
    assert(http::stop_on_signals() == 0);
    let box, e = http::mail_open(16, 256);
    assert(e == 0);
    app::db = http::address(box, 0);
    let db = thread_spawn(app::database, box);
    let id = thread_spawn(worker, cfg);
    thread_wait(id);
    http::mail_send(app::db, app::STOP, "");
    thread_wait(db);
}
