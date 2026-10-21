// The program: its use cases, the state its routes wait with, what every
// lane thread owns, and the routes. As docs/best-practices/lanes/app.goose,
// with Use in place of the tags and Waiting.
import std;
import http;
import rest;
import .proposal;
import .entries;
import .reports;
import .auth;

// Every use case that waits on a lane: the job the lane runs, and what the
// route waits with until the reply.
enum Use {
    None,
    EntryCreate { project: i64, started: i64, stopped: i64 },   // entries::create
    ReportTotals { project: i64 },                              // reports::project
    AuthPassword { email: u8[..64], password: u8[..64] },       // auth::sign_in
    AuthSession { user: i64 },                                  // auth::sign_in, after the password
}

struct St { use: Use = Use.None }

// What each lane thread owns, one type for every lane, so that each lane's
// dispatch finds a run for every variant: the writer's tables, which the
// other lanes' threads hold empty.
struct Db { entries: entries::Entry[>..]&, sessions: auth::Session[>..]& }

struct App { writer: http::Lane, reports: http::Lane, hasher: http::Lane }

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else {
            rest::scope(cx, "/auth") { rest::route(cx) { auth::routes(cx); }; };
            rest::scope(cx, "/entries") { rest::route(cx) { entries::routes(cx); }; };
            rest::scope(cx, "/reports") { rest::route(cx) { reports::routes(cx); }; };
            rest::otherwise(cx);
        }
    };
}

fn run(u: Use.None, db: Db&, a) {}
fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }
