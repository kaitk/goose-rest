// Spike 10: a case function declared in a domain's namespace isn't in the
// global overload set the dispatched call takes. See README.md.
enum Use { None, Report { project: i64 } }

fn resume(u: Use.None) {}
fn reports::resume(u: Use.Report) {}

fn main() {
    let u: Use = Use.Report { project: 3 };
    resume(u);
}
