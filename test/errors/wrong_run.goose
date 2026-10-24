// error: no matching overload for call to run
// A thread that takes the writer lane's jobs, but runs only the reports
// lane's: plod::lane gives each job as a Writes, which no run takes.
import std;
import http from "github.com/kaitk/goose-http@v0.5.9";
import plod from "../../";

enum Writes { Create { project: i64 } }
enum Reports { Totals { project: i64 } }

enum Use { None, Write }

fn run(u: Reports.Totals, a) { plod::reply_value(a, u.project); }

thread_fn writer(box: http::Box, jobs: plod::Jobs<Writes>) {
    plod::lane(box, jobs) { u, a => run(u, a); };
}

fn main() {
    let lane = plod::lane_open<Writes>(http::LaneConfig { .. }, Use.Write, writer);
    plod::lane_stop(lane);
}
