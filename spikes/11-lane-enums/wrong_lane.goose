// error: no matching overload for call to rest::ask
// error: cannot pass Reports.ReportTotals as U
// Spike 11: a report's job sent to the writer lane. The lane is typed by its
// enum, so the call fails to compile. See README.md.
import std;
import http from "github.com/kaitk/goose-http@b5f82a2d302b01c83e6d5073641720238590af22";
import rest from "../../";
import .app;

fn misrouted(cx) {
    rest::ask(cx, cx.app.writer, Reports.ReportTotals { project: 1 });
}

fn main() {
    var a = App {
        writer: rest::Lane<Writes, Use> { lane: http::Lane { .. }, mark: Use.Write },
        reports: rest::Lane<Reports, Use> { lane: http::Lane { .. }, mark: Use.Report },
        hasher: rest::Lane<Hashes, Use> { lane: http::Lane { .. }, mark: Use.Hash },
    };
    print(rest::serve_one("POST / HTTP/1.1\r\n\r\n", a, St { .. }) { cx => misrouted(cx) });
}
