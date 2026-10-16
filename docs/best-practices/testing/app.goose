// The application's entry: the program's types, the job tags, and the routes.
// main.goose imports it to serve, and each test imports it as a package,
// `import app from "../../";`, as a test can't import main.goose.
import std;
import http;
import rest;
import projects.routes;
import entries.routes;

// A job's tag.
let CREATE_ENTRY: i32 = 1;
let STOP: i32 = 2;

// The steps of every route that waits.
enum Waiting {
    None,
    EntryCreate, // entries::create
}

struct St { waiting: Waiting = Waiting.None }

// The projects stand in for a database in the worker's memory; the entries
// are the writer lane's, which the routes ask by mail.
struct App { projects: projects::Project[>..]&, writer: http::MailAddress }

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::scope(cx, "/projects") {
            rest::route(cx) { projects::routes(cx); };
        } else if rest::scope(cx, "/entries") {
            rest::route(cx) { entries::routes(cx); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }
