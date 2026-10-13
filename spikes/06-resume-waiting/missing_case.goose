// Spike 06's case functions without the one for Waiting.None: the dispatched
// call fails to compile. See README.md.
enum Waiting { None, Report { org: i64 }, Export { org: i64 } }

fn resume(w: Waiting.Report) { print("report ", w.org); }
fn resume(w: Waiting.Export) { print("export ", w.org); }

fn main() {
    let w: Waiting = Waiting.Report { org: 3 };
    resume(w);
}
