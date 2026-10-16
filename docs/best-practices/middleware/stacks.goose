// The stacks, one per audience: the middleware each audience's routes run
// behind, and the one rest::route of the request.
import std;
import http;
import rest;
import middleware;

// Routes anyone may call.
inline fn public_routes<F>(cx) {
    // The request's route: a fail from any depth inside, a stack's 401 or a
    // rule's 422, is answered here.
    rest::route(cx) { F(); };
}

// Routes a signed-in user calls.
inline fn user_routes<F>(cx) {
    rest::route(cx) {
        authenticate(cx) { user => F(user); };
    };
}

// Routes a member of the organization the request names calls.
inline fn member_routes<F>(cx) {
    rest::route(cx) {
        authenticate(cx) { user =>
            resolve_organization(cx, user) { member => F(member); };
        };
    };
}
