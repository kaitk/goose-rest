// Plod's framework tiers (bench/rest/tiers), on viltrum's own types:
//
//   F   GET /, GET /id/:id?name= with x-powered-by, and POST /json echoing
//       its body through x.json2's Any, whose objects keep their members'
//       order
//   R   each of ROUTES's lines on viltrum's router, answering its number and
//       its parameters' values
//   M   tier A's routes behind the App's global middleware, outermost first:
//       Server-Timing, viltrum's cors, and a bearer check
module main

import os
import strings
import time
import viltrum
import viltrum.http1
import x.json2

const cors_origin = 'https://app.example'

fn micro_routes(mut app viltrum.App) {
	app.get('/', fn (mut c viltrum.Ctx) {
		c.text(200, 'Hi')
	})
	app.get('/id/:id', fn (mut c viltrum.Ctx) {
		id := c.param('id') or { '' }
		name := c.query_param('name') or { '' }
		c.set_header('x-powered-by', 'benchmark')
		c.text(200, '${id} ${name}')
	})
	app.post('/json', fn (mut c viltrum.Ctx) {
		value := json2.decode[json2.Any](view(c.body())) or {
			c.no_content(400)
			return
		}
		c.bytes(200, 'application/json', value.json_str().bytes())
	})
}

// Route n of the file answers n, then its parameters' values, by spaces; a
// path no line has is the router's 404, and a method a path lacks its 405.
fn github_routes(mut app viltrum.App, file string) {
	text := os.read_file(file) or { stop('${file}: can\'t read') }
	mut n := 0
	for line in text.split_into_lines() {
		words := line.fields()
		if words.len < 2 {
			continue
		}
		n++
		pattern := words[1]
		params := pattern.split('/').filter(it.starts_with(':')).map(it[1..])
		number := n.str()
		app.handle(http1.method_of(words[0]), pattern, fn [number, params] (mut c viltrum.Ctx) {
			mut out := strings.new_builder(64)
			out.write_string(number)
			for name in params {
				out.write_u8(` `)
				out.write_string(c.param(name) or { '' })
			}
			c.bytes(200, 'text/plain; charset=utf-8', out)
		})
	}
}

// Server-Timing around the rest of the chain. viltrum writes a response as
// the handler calls it, so this captures it, as viltrum's gzip does, and
// sends it once the field is set.
fn timing(mut c viltrum.Ctx) {
	sw := time.new_stopwatch()
	c.capture = true
	c.next()
	c.capture = false
	ms := f64(sw.elapsed().nanoseconds()) / 1e6
	c.set_header('Server-Timing', 'app;dur=${ms:.3f}')
	c.send_captured(c.captured_body(), '')
}

fn bearer(mut c viltrum.Ctx) {
	if is_bearer(c.header('authorization')) {
		c.next()
	} else {
		c.no_content(401)
	}
}

// Tier M's stack, as the App's global middleware, which viltrum runs for
// every request, the ones no route takes included.
fn middleware_stack(mut app viltrum.App) {
	app.use(timing)
	app.use(viltrum.cors(cors_origin))
	app.use(bearer)
}
