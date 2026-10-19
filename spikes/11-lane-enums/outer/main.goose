// Spike 11: the other way for the request state to hold the wait, an outer
// enum whose variants hold each lane's enum, with the job in it. A fixed-mode
// enum holds another as its payload, and case functions dispatch on both
// levels. The package can't wrap a lane's job in its variant of the outer
// enum, so each lane needs a function of the program's that does, which a
// generic body in the package's namespace finds by name. See ../README.md.
import std;

enum Writes { Create { project: i64 }, Close { id: i64 } }
enum Reports { Totals { project: i64 } }

// The outer enum: a variant per lane, holding that lane's job.
enum Use { None, Write { job: Writes }, Report { job: Reports } }

struct St { use: Use = Use.None }

// The package's side: ask stores the job through the program's waiting,
// which it finds in the global namespace, and the reset once the route has
// answered.
fn pkg::ask(st: St&, job) { st.use = waiting(job); }
fn pkg::cleared<T>(x: T&) { x = default<T>(); }

// The program's side: one waiting per lane, and one resume per lane that
// dispatches again on the lane's job.
fn waiting(j: Writes) -> Use { Use.Write { job: j } }
fn waiting(j: Reports) -> Use { Use.Report { job: j } }

fn resume(u: Use.None) { print("  not waiting"); }
fn resume(u: Use.Write) { resume(u.job); }
fn resume(u: Use.Report) { resume(u.job); }

fn resume(j: Writes.Create) { print("  resume Writes.Create for project ", j.project); }
fn resume(j: Writes.Close) { print("  resume Writes.Close of ", j.id); }
fn resume(j: Reports.Totals) { print("  resume Reports.Totals for project ", j.project); }

fn size(v) -> i64 {
    var one = [v];
    return bytes_of(one).len;
}

fn main() {
    var st = St { .. };
    pkg::ask(st, Writes.Create { project: 3 });
    print("waits with ", st.use);
    resume(st.use);
    pkg::ask(st, Reports.Totals { project: 4 });
    print("waits with ", st.use);
    resume(st.use);
    pkg::cleared(st.use);
    print("answered: ", st.use);
    resume(st.use);
    print("state: ", size(st), " bytes; Writes ", size(default<Writes>()), ", Reports ",
          size(default<Reports>()));
}
