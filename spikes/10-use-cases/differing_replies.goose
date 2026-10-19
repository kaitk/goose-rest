// Spike 10: run case functions that return replies of different types. The
// dispatched call fails to compile. See README.md.
enum Use { None, Report { project: i64 }, Session { user: i64 } }
struct Totals { seconds: i64 }
struct Opened { id: i64, user: i64 }

fn run(u: Use.None) -> bool { false }
fn run(u: Use.Report) -> Totals { Totals { seconds: u.project * 3600 } }
fn run(u: Use.Session) -> Opened { Opened { id: 1, user: u.user } }

fn main() {
    let u: Use = Use.Report { project: 3 };
    run(u);
}
