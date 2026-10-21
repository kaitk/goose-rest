// The application's entry: the program's types, each lane's jobs, and the
// routes. main.goose imports it to serve, and a test imports it as a
// package, `import app from "../../";`, as a test can't import main.goose.
import std;
import http;
import rest;
import entries.routes;
import reports.routes;
import auth.routes;

// Each lane's jobs: a use case each, and the route that asks for it, a
// route's jobs together and in the order they run.
enum Writes {
    EntryCreate { input: entries::CreateInput },   // entries::create
    AuthSession { user: i64 },                     // auth::sign_in, after the password
}
enum Reports { ReportTotals { project: i64, ms: i64 } }               // reports::project
enum Hashes { AuthPassword { email: u8[..64], password: u8[..64] } }  // auth::sign_in

// The lane a route waits on: a mark for each lane, or None.
enum Use { None, Write, Report, Hash }

struct St { use: Use = Use.None }

// What each lane's thread owns: the writer's tables, the rows the reports
// read, and the users the hasher checks.
struct Writer { entries: entries::Entry[>..]&, sessions: auth::Session[>..]& }
struct Reader { entries: const entries::Entry[:] }
struct Hasher { users: const auth::User[:] }

// The lanes the routes send their jobs to: rest::ask takes a lane's least
// busy thread, and only that lane's jobs.
struct App { writer: rest::Lane<Writes, Use>, reports: rest::Lane<Reports, Use>, hasher: rest::Lane<Hashes, Use> }

fn handle(cx) {
    rest::routes(cx) { cx =>
        rest::get(cx, "/health") { rest::text(cx, 200, "ok"); };
        rest::scope(cx, "/auth") { auth::routes(cx); };
        rest::scope(cx, "/entries") { entries::routes(cx); };
        rest::scope(cx, "/reports") { reports::routes(cx); };
    };
}

// Each mark's resume: the reply carries its job back, which resume
// dispatches on again, to the domain's resume for that job.
fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Write, cx) { resume(rest::job<Writes>(cx), cx); }
fn resume(u: Use.Report, cx) { resume(rest::job<Reports>(cx), cx); }
fn resume(u: Use.Hash, cx) { resume(rest::job<Hashes>(cx), cx); }
