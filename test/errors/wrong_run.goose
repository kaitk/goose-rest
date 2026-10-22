// error: no matching overload for call to run
// A thread that takes the writer lane's jobs, but runs only the reports
// lane's: rest::lane gives each job as a Writes, which no run takes.
import std;
import http from "github.com/kaitk/goose-http@b5f82a2d302b01c83e6d5073641720238590af22";
import rest from "../../";

enum Writes { Create { project: i64 } }
enum Reports { Totals { project: i64 } }

enum Use { None, Write }

fn run(u: Reports.Totals, a) { rest::reply_value(a, u.project); }

thread_fn writer(box: http::Box, jobs: rest::Jobs<Writes>) {
    rest::lane(box, jobs) { u, a => run(u, a); };
}

fn main() {
    let lane = rest::lane_open<Writes>(http::LaneConfig { .. }, Use.Write, writer);
    rest::lane_stop(lane);
}
