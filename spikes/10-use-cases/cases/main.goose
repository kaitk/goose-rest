// Spike 10: two ways case functions behave that the design depends on.
// See ../README.md.
import std;

enum Use { None, Report { project: i64 }, Session { user: i64 } }
struct Totals { project: i64, seconds: i64 }
struct Opened { id: i64, user: i64 }
struct Writer { rows: i64 }

// Case functions whose replies differ in type can't return them (spec
// §8.2: return types must agree; ../differing_replies.goose), but each can
// hand its reply to a block, which is instantiated for each case's type.
fn run<F>(u: Use.None) {}
fn run<F>(u: Use.Report) { F(Totals { project: u.project, seconds: u.project * 3600 }); }
fn run<F>(u: Use.Session) { F(Opened { id: 1, user: u.user }); }

// An overload that takes the whole enum is an exact match, so a call with a
// Use takes it rather than dispatch: a catch-all for the variants a lane
// doesn't run hides the cases it does.
fn take(u, w: Writer&) { print("  take(u, w): not this lane's ", u); }
fn take(u: Use.Report, w: Writer&) { w.rows++; }

fn main() {
    let us: Use[] = [Use.Report { project: 3 }, Use.Session { user: 9 }, Use.None];
    for u in us { run(u) { reply => print("run: ", reply); }; }
    var w = Writer { rows: 0 };
    for u in us { take(u, w); }
    print("rows taken by the Report case: ", w.rows);
}
