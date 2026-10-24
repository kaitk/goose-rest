// Tier A, HttpArena's production-stack application layer:
//
//   GET  /api/items/:id    the item, and servedAt, the time in seconds
//   GET  /api/me           the user X-User-Id names, and servedAt
//   POST /api/items/:id    a body of name, price, and quantity, each optional:
//                          204, or 422; the data doesn't change
//
// An id that isn't one of the records', or isn't a number, is a 404 with an
// empty body, and a missing or unknown user a 401.
module main

import strings
import viltrum
import x.json2

struct Rating {
	score i64
	count i64
}

struct Item {
	id       i64
	name     string
	category string
	price    i64
	quantity i64
	active   bool
	tags     []string
	rating   Rating
}

struct User {
	id    i64
	name  string
	email string
	plan  string
}

// A record with servedAt after its fields, as one JSON object.
struct ServedItem {
	id        i64
	name      string
	category  string
	price     i64
	quantity  i64
	active    bool
	tags      []string
	rating    Rating
	served_at i64 @[json: 'servedAt']
}

struct ServedUser {
	id        i64
	name      string
	email     string
	plan      string
	served_at i64 @[json: 'servedAt']
}

// A write's body: each field optional, and of its type.
struct Write {
	name     ?string
	price    ?i64
	quantity ?i64
}

@[heap]
struct Arena {
	items    []Item
	users    []User
	template bool
	// JSON=template's records, each without its closing brace.
	item_json []string
	user_json []string
}

fn load_arena(cfg Config) &Arena {
	items := parse_file[Item](cfg.dir, 'arena-items.json')
	users := parse_file[User](cfg.dir, 'arena-users.json')
	return &Arena{
		items:     items
		users:     users
		template:  cfg.template
		item_json: if cfg.template { items.map(without_brace(it)) } else { []string{} }
		user_json: if cfg.template { users.map(without_brace(it)) } else { []string{} }
	}
}

fn without_brace[T](record T) string {
	s := json2.encode(record)
	return s[..s.len - 1]
}

// A record's response: its prebuilt JSON with servedAt spliced in.
fn spliced(prebuilt string) Reply {
	mut b := strings.new_builder(prebuilt.len + 24)
	b.write_string(prebuilt)
	b.write_string(',"servedAt":')
	push_int(mut b, now_s())
	b.write_u8(`}`)
	return json_ok(b)
}

fn (a &Arena) item(id string) Reply {
	n := parse_uint(id) or { return arena_not_found() }
	i := index_of(n, a.items.len) or { return arena_not_found() }
	if a.template {
		return spliced(a.item_json[i])
	}
	r := a.items[i]
	return json_ok(written(ServedItem{
		id:        r.id
		name:      r.name
		category:  r.category
		price:     r.price
		quantity:  r.quantity
		active:    r.active
		tags:      r.tags
		rating:    r.rating
		served_at: now_s()
	}))
}

// The id is looked up before the body is read.
fn (a &Arena) write(id string, body string) Reply {
	n := parse_uint(id) or { return arena_not_found() }
	index_of(n, a.items.len) or { return arena_not_found() }
	if !is_object(body) {
		return empty(422)
	}
	json2.decode[Write](body) or { return empty(422) }
	return empty(204)
}

fn (a &Arena) me(user_id ?string) Reply {
	n := parse_uint(user_id or { '' }) or { return empty(401) }
	i := index_of(n, a.users.len) or { return empty(401) }
	if a.template {
		return spliced(a.user_json[i])
	}
	u := a.users[i]
	return json_ok(written(ServedUser{
		id:        u.id
		name:      u.name
		email:     u.email
		plan:      u.plan
		served_at: now_s()
	}))
}

fn arena_not_found() Reply {
	return empty(404)
}

fn arena_routes(mut app viltrum.App, a &Arena) {
	warm(ServedItem{})
	warm(ServedUser{})
	json2.decode[Write]('{}') or {}
	app.get('/api/items/:id', fn [a] (mut c viltrum.Ctx) {
		answer(mut c, a.item(c.param('id') or { '' }))
	})
	app.post('/api/items/:id', fn [a] (mut c viltrum.Ctx) {
		answer(mut c, a.write(c.param('id') or { '' }, view(c.body())))
	})
	app.get('/api/me', fn [a] (mut c viltrum.Ctx) {
		answer(mut c, a.me(c.header('x-user-id')))
	})
}
