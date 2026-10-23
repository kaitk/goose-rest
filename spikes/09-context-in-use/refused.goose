// Spike 09: what the typed router context refuses, each a call that reads a
// router where there is none. goose check refuses the first; README.md has
// each refusal, found by removing the ones before it.
import std;
import http from "github.com/kaitk/goose-http@v0.5.5";
import plod from "../../";
import .api_gen;
import .app;

// At a WAKE: the handler resumes outside plod::routes.
fn resume(cx) { plod::text(cx, 200, plod::param(cx, "id")); }

// A route outside plod::routes.
fn outside(cx) {
    if plod::on(cx, "GET", "/health") { plod::text(cx, 200, "ok"); } else { plod::otherwise(cx); }
}

fn main() {
    var projects: api::Project[>..] = [];
    var live: bool[>..] = [];
    var a = app::App { projects: projects, live: live,
                       db: plod::Lane<app::DbJob, app::Use> { lane: http::Lane { .. }, mark: app::Use.Db } };
    plod::serve(http::Config { .. }, a, app::St { .. }) { cx =>
        if plod::resumed(cx) { plod::route(cx) { resume(cx); }; }
        else if cx.req.method == "TRACE" { outside(cx); }
        // The generated dispatch alone: app::get_project's helper reads :id.
        else { api::dispatch(cx); }
    };
}
