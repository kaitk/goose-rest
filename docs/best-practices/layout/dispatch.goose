// The routes: each audience's scope and stack, then each domain's routes.
import std;
import http;
import rest;
import stacks;
import projects.routes;
import settings.routes;
import teams.routes;

fn handle(cx) {
    rest::timed(cx) {
        rest::routes(cx) { cx =>
            if rest::on(cx, "GET", "/health") {
                public_routes(cx) { rest::text(cx, 200, "ok"); };
            } else if rest::scope(cx, "/settings") {
                user_routes(cx) { user => settings::routes(cx, user); };
            } else if rest::scope(cx, "/organizations") {
                member_routes(cx) { member =>
                    if rest::scope(cx, "/projects") {
                        projects::routes(cx, member);
                    } else if rest::scope(cx, "/teams") {
                        teams::routes(cx, member);
                    } else {
                        rest::otherwise(cx);
                    }
                };
            } else {
                rest::otherwise(cx);
            }
        };
    };
}
