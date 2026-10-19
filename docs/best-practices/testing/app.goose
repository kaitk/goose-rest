// The application's entry: the program's types, the writer lane's jobs, and
// the routes. main.goose imports it to serve, and each test imports it as a
// package, `import app from "../../";`, as a test can't import main.goose.
import std;
import http;
import rest;
import projects.routes;
import entries.routes;

// The writer lane's jobs, and the route that asks for each.
enum Writes {
    EntryCreate { input: entries::CreateInput },   // entries::create
}

// The lane a route waits on.
enum Use { None, Write }

struct St { use: Use = Use.None }

// What the writer lane's thread owns: the entries table's stand-in.
struct Writer { entries: entries::Entry[>..]& }

// The projects stand in for a database in the worker's memory; the entries
// are the writer lane's, which the routes ask by mail.
struct App { projects: projects::Project[>..]&, writer: rest::Lane<Writes, Use> }

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

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Write, cx) { resume(rest::job<Writes>(cx), cx); }
