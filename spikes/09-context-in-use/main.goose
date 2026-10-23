// Spike 09: tasks 015's A and B on a program that does more than the simple
// cases: hand-written routes before the generated dispatch, a route that
// asks another thread and resumes, a helper three calls down that needs the
// router, the worker's state, and the request's, a scope with middleware of
// its own, and per-request state through plod::once. README.md has the
// verdict.
//
// main plays goose-http's loop, as spike 06 does, so that the output is
// fixed: each request goes through plod::on_event, the code plod::serve
// runs, and each reply message addressed to it comes back as a WAKE.
import std;
import http from "github.com/kaitk/goose-http@v0.5.7";
import plod from "../../";
import .api_gen;
import .app;

// A function that types its context names it through an alias: this one
// takes a route's context, inside plod::routes.
type Cx = plod::Cx<app::St, app::App, http::Router>;

let SLOT_SIZE: i64 = 256;

fn handle(cx) {
    if plod::resumed(cx) {
        plod::on_reply(cx) { resume(cx.state.use, cx); };
    } else {
        plod::cors(cx, plod::Cors { origins: "https://app.example", .. }) {
            plod::routes(cx) { cx =>
                if plod::on(cx, "GET", "/health") {
                    plod::text(cx, 200, "ok");
                } else if plod::on(cx, "PUT", "/v1/projects/:id") {
                    plod::route(cx) { rename(cx); };
                } else if plod::on(cx, "GET", "/v1/projects/:id/report") {
                    plod::route(cx) { report(cx); };
                } else {
                    plod::scope(cx, "/admin") { plod::route(cx) { audited(cx) { admin(cx); }; }; };
                    api::dispatch(cx);
                }
            };
        };
    }
}

// The program's own middleware for /admin: an admin's token, counted.
inline fn audited<F>(cx) {
    guard app::user(cx).admin else { plod::fail(cx, 403, "admin_only"); }
    cx.app.audits++;
    F();
}

fn admin(cx) {
    if plod::on(cx, "POST", "/reindex") {
        plod::text(cx, 202, str("reindexing; audits ", cx.app.audits));
    } else {
        plod::otherwise(cx);
    }
}

// PUT /v1/projects/:id?name=..., typed through the alias.
fn rename(cx: Cx&) {
    let p .= app::visible(cx);
    let name, has = plod::query(cx, "name");
    plod::require(cx, "name", has);
    p.name = name;
    plod::json(cx, 200, p);
}

fn report(cx) {
    let p = app::visible(cx);
    plod::ask(cx, cx.app.db, app::DbJob.Report { id: p.id });
}

fn resume(u: app::Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }

fn resume(u: app::Use.Db, cx) { resume(plod::job<app::DbJob>(cx), cx); }

// The reply carries the job back, and the job its project.
fn resume(u: app::DbJob.Report, cx) {
    plod::text(cx, 200, str(cx.app.projects[u.id - 1].name, " has ", plod::answer<i64>(cx), " tasks"));
}

fn run(u: app::DbJob.Report, a) {
    assert(a.piece == SLOT_SIZE);
    plod::reply_value(a, u.id * 3);
}

thread_fn database(box: http::Box, jobs: plod::Jobs<app::DbJob>) {
    plod::lane(box, jobs) { u, a => run(u, a); };
}

// One request through to its whole response, printed without CRs: REQUEST,
// then a WAKE for each reply message addressed to it, as the loops do.
fn exchange<H>(box: http::Box, key: u64, a: app::App&, label: const u8[:], text: const u8[:]) {
    let r, s = http::parse(text);
    assert(s == 200);
    var out: u8[>..] = [];
    var keep = r.keep_alive;
    var stream = http::Stream { later: http::address(box, key), .. };
    var st = plod::Slot<app::St> { state: app::St { .. } };
    let reply = http::Reply { buf: out, common: "", keep_alive: keep, minor: r.minor, head: false, stream: stream };
    plod::on_event(http::Event { kind: http::REQUEST, req: r, data: "", whole: true, trailers: "" }, st, a, reply)
                   { cx => H(cx) };
    var wakes = 0;
    while stream.waiting {
        assert(http::mail_wait(box, 5000));
        http::mail_take(box) { k, tag, bytes =>
            if stream.waiting && k == key {
                stream.waiting = false;
                wakes++;
                plod::on_event(http::Event { kind: http::WAKE, req: r, data: bytes, whole: false, trailers: "",
                                             tag: tag }, st, a, reply) { cx => H(cx) };
            }
        };
    }
    let body = find(out, "\r\n\r\n");
    let line = find(out, "\r\n");
    let allow, has_allow = http::field_in(out[line + 2..body + 2], "Allow");
    print("-- ", label, if wakes > 0 { str(", ", wakes, " wake") } else { str("") }, ": ", out[..line],
          if has_allow { str(" (Allow: ", allow, ")") } else { str("") }, " ", out[body + 4..]);
}

fn get(target: const u8[:], token: const u8[:] = "ada", method: const u8[:] = "GET") -> u8[>..] {
    str(method, " ", target, " HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer ", token, "\r\n\r\n")
}

fn main() {
    let worker, e1 = http::mail_open(16, SLOT_SIZE as i32);
    http::exit_on_error(e1);
    var projects: api::Project[>..] = [];
    var live: bool[>..] = [];
    projects.push(api::Project { id: 1, name: "goose", owner: "ada" });
    projects.push(api::Project { id: 2, name: "gander", owner: "ada" });
    live.push(true);
    live.push(true);
    var a = app::App { projects: projects, live: live,
                       db: plod::lane_open<app::DbJob>(http::LaneConfig { slots: 16, .. }, app::Use.Db, database) };
    var key: u64 = 0;
    fn served(label: const u8[:], text: const u8[:]) {
        key++;
        exchange(worker, key, a, label, text) { cx => handle(cx) };
    }
    served("health", get("/health"));
    served("generated GET, helper reads :id", get("/v1/projects/1"));
    served("generated GET, another's project", get("/v1/projects/2", "bob"));
    served("hand-written PUT before dispatch", get("/v1/projects/1?name=swan", "ada", "PUT"));
    served("405 across both", get("/v1/projects/1", "ada", "POST"));
    served("asks the database, resumes", get("/v1/projects/2/report"));
    served("scope with its own middleware", get("/admin/reindex", "ada", "POST"));
    served("the same, refused", get("/admin/reindex", "bob", "POST"));
    served("plod::once across check and handler", get("/v1/projects"));
    served("generated DELETE", get("/v1/projects/2", "ada", "DELETE"));
    print("audits ", a.audits, ", lookups ", a.lookups);
    plod::lane_stop(a.db);
    http::mail_close(worker);
}
