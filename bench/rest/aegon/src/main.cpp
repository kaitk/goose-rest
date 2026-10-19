// goose-http's REST benchmark tiers on Aegon, each route on Aegon's Router
// and route groups with its middleware, run as HttpArena's Aegon entry runs
// its server: WORKERS threads, each an io_uring event loop pinned to a CPU,
// with the entry's ring and provided-buffer sizes, and jemalloc (NOTES.md).
//
//   REST_DATA=DIR TIER=a|b|c|d|f|r|m WORKERS=n [JSON=template] [ROUTES=FILE]
//       rest-aegon|rest-aegon-small [port]
//
// rest-aegon takes the entry's buffers for an unlimited memlock limit, 16,384
// of 4 KB per thread on a ring of 8,192 entries, and rest-aegon-small its
// buffers for a low limit, 256 on a ring of 512.
//
// TIER picks the dataset and the routes: tier D serves tier C's beside its
// own, and tier M tier A's behind its middleware.

#include "app.h"
#include "http/Server.h"

namespace {

using namespace app;

bool in_scope(std::string_view path, std::string_view prefix) {
    return path.starts_with(prefix) && (path.size() == prefix.size() || path[prefix.size()] == '/');
}

// The answer to a path no route takes, or a method its route lacks: the
// tier's own under its scope, and an empty 404 elsewhere, as tier A's
// unknown paths answer.
Reply fallback(std::string_view path) {
    switch (config().tier) {
    case Tier::B:
        if (in_scope(path, "/api/v1")) return snow::not_found();
        break;
    case Tier::C:
        if (in_scope(path, "/api/v2")) return heavy::not_found();
        break;
    case Tier::D:
        if (in_scope(path, "/api/v2") || in_scope(path, "/api/v3")) return heavy::not_found();
        break;
    default:
        break;
    }
    return arena::not_found();
}

}  // namespace

int main(int argc, char** argv) {
    const Config& cfg = init(argc, argv);

    aegon::http::Server server;
#ifdef AEGON_SMALL
    server.ring_entries(512);
    server.buffer_pool_entries(256);
#else
    server.ring_entries(8192);
    server.buffer_pool_entries(16384);
#endif
    server.max_body_size(16 << 20);

    auto& router = server.router();
    switch (cfg.tier) {
    case Tier::A: arena::routes(router); break;
    case Tier::B: snow::routes(router); break;
    case Tier::C: heavy::routes(router); break;
    case Tier::D:
        heavy::routes(router);
        writes::routes(router);
        break;
    case Tier::F: framework::micro(router); break;
    case Tier::R: framework::github(router); break;
    case Tier::M:
        framework::middleware(router);
        arena::routes(router);
        break;
    }
    auto not_found = [](aegon::http::Context& ctx) { answer(ctx, fallback(ctx.req().path())); };
    router.set_not_found_handler(not_found);
    router.set_method_not_allowed_handler(not_found);

    server.listen(cfg.port);
    server.run(cfg.workers);
    return 0;
}
