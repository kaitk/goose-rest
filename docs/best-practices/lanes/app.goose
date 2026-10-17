// The application's entry: the program's types, the job tags, and the routes.
// main.goose imports it to serve, and a test imports it as a package,
// `import app from "../../";`, as a test can't import main.goose.
import std;
import http;
import rest;
import entries.routes;
import reports.routes;
import auth.routes;

// A job's tag.
let CREATE_ENTRY: i32 = 1;
let TOTAL_ENTRIES: i32 = 2;
let VERIFY_PASSWORD: i32 = 3;
let OPEN_SESSION: i32 = 4;

// The steps of every route that waits, a route's steps together and in the
// order they run.
enum Waiting {
    None,
    EntryCreate,               // entries::create
    ReportTotals,              // reports::project
    AuthPassword, AuthSession, // auth::sign_in
}

struct St { waiting: Waiting = Waiting.None }

// The lanes the routes send their jobs to: rest::ask takes a lane's least
// busy thread.
struct App { writer: rest::Lane, reports: rest::Lane, hasher: rest::Lane }

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::scope(cx, "/auth") {
            rest::route(cx) { auth::routes(cx); };
        } else if rest::scope(cx, "/entries") {
            rest::route(cx) { entries::routes(cx); };
        } else if rest::scope(cx, "/reports") {
            rest::route(cx) { reports::routes(cx); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }
