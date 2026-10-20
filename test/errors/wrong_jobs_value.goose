// error: expected a value of type rest::Jobs<Reports>, got rest::Jobs<Writes>
// wrong_jobs.goose's lane, opened with a value each thread takes too.
import std;
import http from "github.com/kaitk/goose-http@v0.4.1";
import rest from "../../";
enum Writes { Create { project: i64 } }
enum Reports { Totals { project: i64 } }
enum Use { None, Write }
fn run(u: Reports.Totals, d: i64, a) { rest::reply_value(a, u.project); }
thread_fn reader(box: http::Box, jobs: rest::Jobs<Reports>, d: i64) {
    rest::lane(box, jobs) { u, a => run(u, d, a); };
}
fn main() {
    let writer = rest::lane_open<Writes>(http::LaneConfig { .. }, Use.Write, 5, reader);
    rest::lane_stop(writer);
}
