// The application's entry: the program's types, each lane's jobs, and the
// routes. main.goose imports it to serve, and a test imports it as a
// package, `import app from "../../";`, as a test can't import main.goose.
import std;
import http;
import plod;
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

// The lanes the routes send their jobs to: plod::ask takes a lane's least
// busy thread, and only that lane's jobs.
struct App { writer: plod::Lane<Writes, Use>, reports: plod::Lane<Reports, Use>, hasher: plod::Lane<Hashes, Use> }

fn handle(cx) {
    plod::routes(cx) { cx =>
        plod::get(cx, "/health") { plod::text(cx, 200, "ok"); };
        plod::scope(cx, "/auth") { auth::routes(cx); };
        plod::scope(cx, "/entries") { entries::routes(cx); };
        plod::scope(cx, "/reports") { reports::routes(cx); };
    };
}

// Each mark's resume: the reply carries its job back, which resume
// dispatches on again, to the domain's resume for that job.
fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Write, cx) { resume(plod::job<Writes>(cx), cx); }
fn resume(u: Use.Report, cx) { resume(plod::job<Reports>(cx), cx); }
fn resume(u: Use.Hash, cx) { resume(plod::job<Hashes>(cx), cx); }
