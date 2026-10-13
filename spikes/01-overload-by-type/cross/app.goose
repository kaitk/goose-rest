namespace app;

import std;
import rest;

struct Session { user: i64 }
struct Page { n: i64 }

fn rest::from_request(cx: rest::Cx&, v: app::Session&) { v.user = app::user_of(cx.cookie); }
fn rest::from_request(cx: rest::Cx&, v: app::Page&) { v.n = cx.page; }

fn user_of(cookie: const u8[:]) -> i64 { if cookie == "ok" { 7 } else { 0 } }

fn handle(cx: rest::Cx&) {
    rest::take<Session>(cx) { s => print("session ", s.user); };
    rest::take<Page>(cx) { p => print("page ", p.n); };
    rest::take<rest::Query>(cx) { q => print("query ", q.raw); };
}
