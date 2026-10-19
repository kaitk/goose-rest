// The program: each lane's jobs, the mark a route waits with, what each
// lane's thread owns, and the routes. As spike 10's app.goose, with an enum
// per lane in place of the one Use, and a Use of marks.
import std;
import http;
import rest;
import .proposal;
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

struct App { writer: rest::Lane<Writes, Use>, reports: rest::Lane<Reports, Use>, hasher: rest::Lane<Hashes, Use> }

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

// Each mark's resume: the job the reply carries back, dispatched again.
fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Write, cx) { resume(rest::job<Writes>(cx), cx); }
fn resume(u: Use.Report, cx) { resume(rest::job<Reports>(cx), cx); }
fn resume(u: Use.Hash, cx) { resume(rest::job<Hashes>(cx), cx); }
