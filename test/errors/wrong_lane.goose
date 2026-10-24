// error: no matching overload for call to plod::ask
// A report's job sent to the writer lane: a lane takes only its own enum's
// variants, and the candidate's note says "cannot pass Reports.Totals as U".
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";

enum Writes { Create { project: i64 } }
enum Reports { Totals { project: i64 } }

enum Use { None, Write, Report }

struct St { use: Use = Use.None }

struct App { writer: plod::Lane<Writes, Use>, reports: plod::Lane<Reports, Use> }

fn main() {
    var a = App {
        writer: plod::Lane<Writes, Use> { lane: http::Lane { .. }, mark: Use.Write },
        reports: plod::Lane<Reports, Use> { lane: http::Lane { .. }, mark: Use.Report },
    };
    print(plod::serve_one("POST / HTTP/1.1\r\n\r\n", a, St { .. }) { cx =>
        plod::ask(cx, cx.app.writer, Reports.Totals { project: 1 });
    });
}
