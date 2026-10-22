import std;
import http from "github.com/kaitk/goose-http@v0.5.4";
import plod from "../../";
import expect from "../";
import security_common;

struct SecurityApp { lane: Lane }

fn main() {
    let box, e = http::mail_open(2, 256);
    http::exit_on_error(e);
    let lane = plod::lane_of<Reports>(box, Use.Report);
    var app = SecurityApp { lane: lane };
    let reply = reported(lane);
    var options = plod::security_api();
    options.frame_options = "";
    let cfg = plod::prepare_security_headers(options);
    for timing in [0, 1, 2] {
        for timeout in [false, true] {
            let wakes = [if timeout { plod::Wake { timeout: true, .. } } else { plod::wake(reply) }];
            let out = plod::serve_one(expect::request("GET", "/report"), app, St { .. }, wakes) { cx =>
                if plod::resumed(cx) { plod::on_reply(cx) { resume(cx.state.use, cx); }; }
                else {
                    if timing == 0 {
                        plod::security_headers(cx, cfg) {
                            plod::ask(cx, cx.app.lane, Reports.Report);
                            cx.scratch.append("unrelated scratch bytes");
                        };
                    } else if timing == 1 {
                        plod::timed(cx, false) {
                            plod::security_headers(cx, cfg) { plod::ask(cx, cx.app.lane, Reports.Report); };
                        };
                    } else {
                        plod::security_headers(cx, cfg) {
                            plod::timed(cx, false) { plod::ask(cx, cx.app.lane, Reports.Report); };
                        };
                    }
                }
            };
            security_omitted(out, "X-Frame-Options");
            security_header(out, "Content-Security-Policy", "frame-ancestors 'none'");
            security_header(out, "Cache-Control", "no-store");
            security_header(out, "Strict-Transport-Security", "max-age=31536000; includeSubDomains");
            if timing != 0 { timing_in(out, 0); }
            expect::same(expect::status_of(out), if timeout { "HTTP/1.1 504 Gateway Timeout" } else { "HTTP/1.1 200 OK" });
            expect::same(expect::body_of(out), if timeout { "{\"error\":\"timeout\"}" } else { "got 42" });
            http::mail_take(box) { key, tag, bytes => };
        }
    }
    let upload = plod::serve_one("POST /upload HTTP/1.1\r\nContent-Length: 5\r\n\r\nhello", app, St { .. }) { cx =>
        if plod::resumed(cx) { plod::on_reply(cx) { resume(cx.state.use, cx); }; }
        else { plod::security_headers(cx, cfg) { plod::body_in_pieces(cx, 100, Use.Upload); }; }
    };
    security_omitted(upload, "X-Frame-Options");
    security_header(upload, "Cache-Control", "no-store");
    expect::same(expect::body_of(upload), "5");
    http::mail_close(box);
    print("security headers on deferred answers and timeout: ok");
}
