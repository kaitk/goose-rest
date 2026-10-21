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
            public_routes(cx) { rest::get(cx, "/health") { rest::text(cx, 200, "ok"); }; };
            rest::scope(cx, "/settings") {
                // Authenticates, or answers 401; the block gets the user.
                user_routes(cx) { user => settings::routes(cx, user); };
            };
            rest::scope(cx, "/organization") {
                // The user, then their membership of the organization the
                // request names; the block gets the member. A stranger gets
                // 401 for any path here, not 404.
                member_routes(cx) { member =>
                    rest::scope(cx, "/projects") { projects::routes(cx, member); };
                    rest::scope(cx, "/teams") { teams::routes(cx, member); };
                };
            };
        };
    };
}
