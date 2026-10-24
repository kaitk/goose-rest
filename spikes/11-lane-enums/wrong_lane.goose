// error: no matching overload for call to plod::ask
// error: cannot pass Reports.ReportTotals as U
// Spike 11: a report's job sent to the writer lane. The lane is typed by its
// enum, so the call fails to compile. See README.md.
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";
import .app;

fn misrouted(cx) {
    plod::ask(cx, cx.app.writer, Reports.ReportTotals { project: 1 });
}

fn main() {
    var a = App {
        writer: plod::Lane<Writes, Use> { lane: http::Lane { .. }, mark: Use.Write },
        reports: plod::Lane<Reports, Use> { lane: http::Lane { .. }, mark: Use.Report },
        hasher: plod::Lane<Hashes, Use> { lane: http::Lane { .. }, mark: Use.Hash },
    };
    print(plod::serve_one("POST / HTTP/1.1\r\n\r\n", a, St { .. }) { cx => misrouted(cx) });
}
