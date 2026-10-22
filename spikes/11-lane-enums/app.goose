// The program: each lane's jobs, the mark a route waits with, what each
// lane's thread owns, and the routes. As spike 10's app.goose, with an enum
// per lane in place of the one Use, and a Use of marks.
import std;
import http;
import plod;
import .entries;
import .reports;
import .auth;

// Each lane's use cases: the jobs its threads run.
enum Writes {
    EntryCreate { project: i64, started: i64, stopped: i64 },   // entries::create
    AuthSession { user: i64 },                                  // auth::sign_in, after the password
}
enum Reports { ReportTotals { project: i64 } }                  // reports::project
enum Hashes { AuthPassword { email: u8[..64], password: u8[..64] } }   // auth::sign_in

// The lane a route waits on: one mark per lane, None first.
enum Use { None, Write, Report, Hash }

struct St { use: Use = Use.None }

// What each lane's thread owns: the writer's tables, the rows the reports
// read, and the users the hasher checks.
struct Writer { entries: entries::Entry[>..]&, sessions: auth::Session[>..]& }
struct Reader { entries: const entries::Entry[:] }
struct Hasher { users: const auth::User[:] }

struct App { writer: plod::Lane<Writes, Use>, reports: plod::Lane<Reports, Use>, hasher: plod::Lane<Hashes, Use> }

fn handle(cx) {
    plod::routes(cx) { cx =>
        if plod::on(cx, "GET", "/health") {
            plod::text(cx, 200, "ok");
        } else {
            plod::scope(cx, "/auth") { plod::route(cx) { auth::routes(cx); }; };
            plod::scope(cx, "/entries") { plod::route(cx) { entries::routes(cx); }; };
            plod::scope(cx, "/reports") { plod::route(cx) { reports::routes(cx); }; };
            plod::otherwise(cx);
        }
    };
}

// Each mark's resume: the job the reply carries back, dispatched again.
fn resume(u: Use.None, cx) { plod::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Write, cx) { resume(plod::job<Writes>(cx), cx); }
fn resume(u: Use.Report, cx) { resume(plod::job<Reports>(cx), cx); }
fn resume(u: Use.Hash, cx) { resume(plod::job<Hashes>(cx), cx); }
