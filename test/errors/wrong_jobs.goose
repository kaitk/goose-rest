// error: expected a value of type rest::Jobs<Reports>, got rest::Jobs<Writes>
// A lane of Writes opened with a thread that takes the reports lane's jobs:
// thread_spawn checks the thread's rest::Jobs against lane_open's.
import std;
import http from "github.com/kaitk/goose-http@v0.5.3";
import rest from "../../";

enum Writes { Create { project: i64 } }
enum Reports { Totals { project: i64 } }

enum Use { None, Write }

fn run(u: Reports.Totals, a) { rest::reply_value(a, u.project); }

thread_fn reader(box: http::Box, jobs: rest::Jobs<Reports>) {
    rest::lane(box, jobs) { u, a => run(u, a); };
}

fn main() {
    let writer = rest::lane_open<Writes>(http::LaneConfig { .. }, Use.Write, reader);
    rest::lane_stop(writer);
}
