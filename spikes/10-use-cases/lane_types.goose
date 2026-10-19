// Spike 10: run case functions that take each lane's own state. A lane's
// dispatched call needs a case for every variant with its state's type, so
// the writer's call fails to compile without the report's. See README.md.
enum Use { None, Report { project: i64 }, Create { project: i64 } }
struct Writer { rows: i64 }
struct Reader { reads: i64 }

fn run(u: Use.None, w: Writer&) {}
fn run(u: Use.Create, w: Writer&) { w.rows++; }
fn run(u: Use.Report, r: Reader&) { r.reads++; }

fn main() {
    var w = Writer { rows: 0 };
    let u: Use = Use.Create { project: 3 };
    run(u, w);
}
