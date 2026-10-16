// The routes: each audience's scope and stack, then each domain's routes.
import std;
import http;
import rest;
import stacks;
import projects.routes;
import settings.routes;
import teams.routes;

fn handle(cx) {
    // Middleware every answer gets, the 404s included, goes outside the routes.
    rest::timed(cx) {
        rest::routes(cx) { cx =>
            // A scope per audience, each behind its stack (stacks.goose).
            if rest::on(cx, "GET", "/health") {
                public_routes(cx) { rest::text(cx, 200, "ok"); };
            } else if rest::scope(cx, "/settings") {
                // Authenticates, or answers 401; the block gets the user.
                user_routes(cx) { user => settings::routes(cx, user); };
            } else if rest::scope(cx, "/organization") {
                // The user, then their membership of the organization the
                // request names; the block gets the member.
                member_routes(cx) { member =>
                    if rest::scope(cx, "/projects") {
                        projects::routes(cx, member);
                    } else if rest::scope(cx, "/teams") {
                        teams::routes(cx, member);
                    } else {
                        // Behind the stack: a stranger gets 401, not 404.
                        rest::otherwise(cx);
                    }
                };
            } else {
                rest::otherwise(cx);
            }
        };
    };
}
