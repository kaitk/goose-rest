// error: expected a value of type plod::Jobs<Reports>, got plod::Jobs<Writes>
// wrong_jobs.goose's lane, opened with a value each thread takes too.
import std;
import http from "github.com/kaitk/goose-http@v0.5.8";
import plod from "../../";
enum Writes { Create { project: i64 } }
enum Reports { Totals { project: i64 } }
enum Use { None, Write }
fn run(u: Reports.Totals, d: i64, a) { plod::reply_value(a, u.project); }
thread_fn reader(box: http::Box, jobs: plod::Jobs<Reports>, d: i64) {
    plod::lane(box, jobs) { u, a => run(u, d, a); };
}
fn main() {
    let writer = plod::lane_open<Writes>(http::LaneConfig { .. }, Use.Write, 5, reader);
    plod::lane_stop(writer);
}
