// Plod's framework tiers (bench/rest/tiers), on Aegon's own types:
//
//   F   GET /, GET /id/:id?name= with x-powered-by, and POST /json echoing
//       its body through glz::generic, whose objects keep their members' order
//   R   each of ROUTES's lines on Aegon's router, answering its number and
//       its parameters' values
//   M   tier A's routes behind the router's global middleware, outermost
//       first: Server-Timing, Aegon's cors, and a bearer check

#include <chrono>
#include <cstdio>
#include <fstream>
#include <sstream>
#include <vector>

#include <glaze/glaze.hpp>

#include "app.h"
#include "http/middleware/Cors.h"

namespace app::framework {

using aegon::http::Context;
using aegon::http::Method;
using aegon::http::Next;

void micro(aegon::http::Router& router) {
    router.get("/", [](Context& ctx) { ctx.res().text("Hi"); });
    router.get("/id/:id", [](Context& ctx) {
        auto& req = ctx.req();
        std::string body(*req.param("id"));
        body.push_back(' ');
        body.append(aegon::http::Request::url_decode(req.query_param("name").value_or("")));
        ctx.res().text(body).header("x-powered-by", "benchmark");
    });
    router.post("/json", [](Context& ctx) {
        glz::generic value;
        if (glz::read_json(value, ctx.req().body())) {
            answer(ctx, Reply::empty(400));
            return;
        }
        ctx.res().json(value);
    });
}

namespace {

// A route of ROUTES: its number, method, pattern, and parameter names.
struct Route {
    size_t n;
    Method method;
    std::string pattern;
    std::vector<std::string> params;
};

std::vector<Route> github_routes() {
    const std::string& file = config().routes;
    std::ifstream f(file);
    if (!f) {
        std::fprintf(stderr, "%s: can't read\n", file.c_str());
        std::exit(1);
    }
    std::vector<Route> routes;
    std::string line;
    while (std::getline(f, line)) {
        if (line.empty()) continue;
        std::istringstream words(line);
        std::string method, pattern;
        words >> method >> pattern;
        Route r{routes.size() + 1, aegon::http::string_to_method(method), pattern, {}};
        std::istringstream segments(pattern);
        std::string seg;
        while (std::getline(segments, seg, '/')) {
            if (seg.starts_with(':')) r.params.push_back(seg.substr(1));
        }
        routes.push_back(std::move(r));
    }
    return routes;
}

}  // namespace

// Route n of the file answers n, then its parameters' values, by spaces.
void github(aegon::http::Router& router) {
    for (Route& r : github_routes()) {
        std::string pattern = r.pattern;
        router.add_route(r.method, pattern, [r = std::move(r)](Context& ctx) {
            std::string out = std::to_string(r.n);
            for (const auto& name : r.params) {
                out.push_back(' ');
                out.append(*ctx.req().param(name));
            }
            ctx.res().text(out);
        });
    }
}

// Tier M's stack, as the router's global middleware, which Aegon runs for
// every request, the ones no route takes included.
void middleware(aegon::http::Router& router) {
    router.use([](Context& ctx, Next next) -> aegon::core::Task<void> {
        auto start = std::chrono::steady_clock::now();
        co_await next(ctx);
        double ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
        char buf[48];
        int n = std::snprintf(buf, sizeof buf, "app;dur=%.3f", ms);
        ctx.res().set_header_owned("Server-Timing", std::string(buf, n));
    });
    aegon::http::middleware::CorsConfig cors;
    cors.allowed_origins = {"https://app.example"};
    cors.allowed_methods = {Method::GET, Method::POST};
    cors.allowed_headers = {"Authorization", "Content-Type"};
    router.use(aegon::http::middleware::cors(std::move(cors)));
    router.use([](Context& ctx, Next next) -> aegon::core::Task<void> {
        if (is_bearer(ctx.req().header("authorization"))) {
            co_await next(ctx);
        } else {
            answer(ctx, Reply::empty(401));
        }
    });
}

}  // namespace app::framework
