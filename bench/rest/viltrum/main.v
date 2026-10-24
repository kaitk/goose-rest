// goose-http's REST benchmark tiers on viltrum, each route on viltrum's App
// and groups with its middleware, run as HttpArena's viltrum entry runs its
// server: v -prod, one SO_REUSEPORT epoll worker per CPU (NOTES.md).
//
//   REST_DATA=DIR TIER=a|b|c|d|f|r|m WORKERS=n [JSON=template] [ROUTES=FILE]
//       rest-viltrum [port]
//
// TIER picks the dataset and the routes: tier D serves tier C's beside its
// own, and tier M tier A's behind its middleware.
module main

import viltrum
import viltrum.http1

// Every method but HEAD, which the router answers through GET.
const methods = [viltrum.Method.get, .post, .put, .delete, .patch, .options, .connect, .trace,
	.other]

// fallback answers each method on a path under prefix that no route above it
// takes with r: the tier's own 404 under its scope, and an empty 404
// elsewhere, as tier A's unknown paths answer. viltrum's App has no not-found
// handler of its own, so a wildcard route registered after the tier's routes
// takes its place; its router tries routes with parameters in the order
// they're registered.
fn fallback(mut app viltrum.App, prefix string, r Reply) {
	for m in methods {
		app.handle(m, prefix + '/*rest', fn [r] (mut c viltrum.Ctx) {
			answer(mut c, r)
		})
	}
}

fn main() {
	cfg := config()
	mut app := viltrum.new()
	app.server_options(viltrum.Options{
		workers: cfg.workers
		limits:  http1.Limits{
			max_body_bytes: 16 << 20
		}
	})
	mut records := 0
	match cfg.tier {
		.a {
			a := load_arena(cfg)
			records = a.items.len
			arena_routes(mut app, a)
		}
		.b {
			s := load_snow(cfg)
			records = s.entries.len
			snow_routes(mut app, s)
			fallback(mut app, '/api/v1', snow_not_found())
		}
		.c, .d {
			h := load_heavy(cfg)
			records = h.records()
			heavy_routes(mut app, h)
			if cfg.tier == .d {
				writes_routes(mut app)
				fallback(mut app, '/api/v3', heavy_not_found())
			}
			fallback(mut app, '/api/v2', heavy_not_found())
		}
		.f {
			micro_routes(mut app)
		}
		.r {
			github_routes(mut app, cfg.routes)
		}
		.m {
			a := load_arena(cfg)
			records = a.items.len
			middleware_stack(mut app)
			arena_routes(mut app, a)
		}
	}

	if cfg.tier in [.a, .b, .c, .d] {
		fallback(mut app, '', arena_not_found())
	}
	println('rest-viltrum: tier ${cfg.tier_name}, ${records} records, ${app.worker_count()} workers on port ${cfg.port}, ${if cfg.template {
		'template'
	} else {
		'serialize'
	}}')
	app.listen('0.0.0.0:${cfg.port}') or { stop(err.msg()) }
}
