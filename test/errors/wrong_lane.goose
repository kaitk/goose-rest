// error: no matching overload for call to rest::ask
// A report's job sent to the writer lane: a lane takes only its own enum's
// variants, and the candidate's note says "cannot pass Reports.Totals as U".
import std;
import http from "github.com/kaitk/goose-http@v0.5.2";
import rest from "../../";

enum Writes { Create { project: i64 } }
enum Reports { Totals { project: i64 } }

enum Use { None, Write, Report }

struct St { use: Use = Use.None }

struct App { writer: rest::Lane<Writes, Use>, reports: rest::Lane<Reports, Use> }

fn main() {
    var a = App {
        writer: rest::Lane<Writes, Use> { lane: http::Lane { .. }, mark: Use.Write },
        reports: rest::Lane<Reports, Use> { lane: http::Lane { .. }, mark: Use.Report },
    };
    print(rest::serve_one("POST / HTTP/1.1\r\n\r\n", a, St { .. }) { cx =>
        rest::ask(cx, cx.app.writer, Reports.Totals { project: 1 });
    });
}
