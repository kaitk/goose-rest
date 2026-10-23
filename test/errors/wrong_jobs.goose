// error: expected a value of type plod::Jobs<Reports>, got plod::Jobs<Writes>
// A lane of Writes opened with a thread that takes the reports lane's jobs:
// thread_spawn checks the thread's plod::Jobs against lane_open's.
import std;
import http from "github.com/kaitk/goose-http@v0.5.5";
import plod from "../../";

enum Writes { Create { project: i64 } }
enum Reports { Totals { project: i64 } }

enum Use { None, Write }

fn run(u: Reports.Totals, a) { plod::reply_value(a, u.project); }

thread_fn reader(box: http::Box, jobs: plod::Jobs<Reports>) {
    plod::lane(box, jobs) { u, a => run(u, a); };
}

fn main() {
    let writer = plod::lane_open<Writes>(http::LaneConfig { .. }, Use.Write, reader);
    plod::lane_stop(writer);
}
