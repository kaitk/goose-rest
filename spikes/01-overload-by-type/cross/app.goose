namespace app;

import std;
import plod;

struct Session { user: i64 }
struct Page { n: i64 }

fn plod::from_request(cx: plod::Cx&, v: app::Session&) { v.user = app::user_of(cx.cookie); }
fn plod::from_request(cx: plod::Cx&, v: app::Page&) { v.n = cx.page; }

fn user_of(cookie: const u8[:]) -> i64 { if cookie == "ok" { 7 } else { 0 } }

fn handle(cx: plod::Cx&) {
    plod::take<Session>(cx) { s => print("session ", s.user); };
    plod::take<Page>(cx) { p => print("page ", p.n); };
    plod::take<plod::Query>(cx) { q => print("query ", q.raw); };
}
