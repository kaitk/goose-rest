// Spike 09: what the typed router context refuses, each a call that reads a
// router where there is none. goose check refuses the first; README.md has
// each refusal, found by removing the ones before it.
import std;
import http from "github.com/kaitk/goose-http@v0.4.0";
import rest from "../../";
import .api_gen;
import .app;

// At a WAKE: the handler resumes outside rest::routes.
fn resume(cx) { rest::text(cx, 200, rest::param(cx, "id")); }

// A route outside rest::routes.
fn outside(cx) {
    if rest::on(cx, "GET", "/health") { rest::text(cx, 200, "ok"); } else { rest::otherwise(cx); }
}

fn main() {
    var projects: api::Project[>..] = [];
    var live: bool[>..] = [];
    var a = app::App { projects: projects, live: live,
                       db: rest::Lane<app::DbJob, app::Use> { lane: http::Lane { .. }, mark: app::Use.Db } };
    rest::serve(http::Config { .. }, a, app::St { .. }) { cx =>
        if rest::resumed(cx) { rest::route(cx) { resume(cx); }; }
        else if cx.req.method == "TRACE" { outside(cx); }
        // The generated dispatch alone: app::get_project's helper reads :id.
        else { api::dispatch(cx); }
    };
}
