// Tier A, HttpArena's production-stack application layer:
//
//   GET  /api/items/:id    the item, and servedAt, the time in seconds
//   GET  /api/me           the user X-User-Id names, and servedAt
//   POST /api/items/:id    a body of name, price, and quantity, each optional:
//                          204, or 422; the data doesn't change
//
// An id that isn't one of the records', or isn't a number, is a 404 with an
// empty body, and a missing or unknown user a 401.

use serde::{Deserialize, Serialize};

use crate::{data, index_of, json, now_s, read_file, Reply};

#[derive(Deserialize, Serialize)]
struct Rating {
    score: i64,
    count: i64,
}

#[derive(Deserialize, Serialize)]
struct Item {
    id: i64,
    name: String,
    category: String,
    price: i64,
    quantity: i64,
    active: bool,
    tags: Vec<String>,
    rating: Rating,
}

#[derive(Deserialize, Serialize)]
struct User {
    id: i64,
    name: String,
    email: String,
    plan: String,
}

// A record with servedAt after its fields, as one JSON object.
#[derive(Serialize)]
struct Served<'a, T> {
    #[serde(flatten)]
    record: &'a T,
    #[serde(rename = "servedAt")]
    served_at: u64,
}

// A write's body: each field optional, and of its type. A server reads it
// with its framework's JSON extractor.
#[derive(Deserialize)]
#[allow(dead_code)]
pub struct Write {
    name: Option<String>,
    price: Option<i64>,
    quantity: Option<i64>,
}

#[derive(Default)]
pub(crate) struct Arena {
    items: Vec<Item>,
    users: Vec<User>,
    // JSON=template's records, each without its closing brace.
    item_json: Vec<Vec<u8>>,
    user_json: Vec<Vec<u8>>,
}

fn without_brace(mut v: Vec<u8>) -> Vec<u8> {
    v.pop();
    v
}

impl Arena {
    pub(crate) fn load(dir: &str, template: bool) -> Arena {
        let mut a = Arena::default();
        a.items = serde_json::from_slice(&read_file(dir, "arena-items.json")).expect("arena-items.json");
        a.users = serde_json::from_slice(&read_file(dir, "arena-users.json")).expect("arena-users.json");
        if template {
            a.item_json = a.items.iter().map(|i| without_brace(serde_json::to_vec(i).unwrap())).collect();
            a.user_json = a.users.iter().map(|u| without_brace(serde_json::to_vec(u).unwrap())).collect();
        }
        a
    }

    pub(crate) fn records(&self) -> usize {
        self.items.len()
    }
}

// A record's response: its prebuilt JSON with servedAt spliced in, or the
// record and servedAt serialized.
fn served<T: Serialize>(record: &T, prebuilt: Option<&Vec<u8>>) -> Reply {
    let now = now_s();
    let body = match prebuilt {
        Some(p) => {
            let mut b = Vec::with_capacity(p.len() + 24);
            b.extend_from_slice(p);
            b.extend_from_slice(b",\"servedAt\":");
            b.extend_from_slice(now.to_string().as_bytes());
            b.push(b'}');
            b
        }
        None => serde_json::to_vec(&Served { record, served_at: now }).unwrap(),
    };
    json(body)
}

pub fn not_found() -> Reply {
    Reply::empty(404)
}

// GET /api/items/:id.
pub fn item(id: usize) -> Reply {
    let d = data();
    match index_of(id, d.arena.items.len()) {
        Some(i) => served(&d.arena.items[i], d.template.then(|| &d.arena.item_json[i])),
        None => not_found(),
    }
}

// POST /api/items/:id, with whether its body read as a Write: the id is
// looked up first.
pub fn write(id: usize, valid: bool) -> Reply {
    if index_of(id, data().arena.items.len()).is_none() {
        return not_found();
    }
    Reply::empty(if valid { 204 } else { 422 })
}

// GET /api/me, with X-User-Id's value.
pub fn me(user_id: Option<&[u8]>) -> Reply {
    let d = data();
    let user = user_id.and_then(|v| std::str::from_utf8(v).ok()).and_then(|v| v.parse::<usize>().ok())
        .and_then(|v| index_of(v, d.arena.users.len()));
    match user {
        Some(i) => served(&d.arena.users[i], d.template.then(|| &d.arena.user_json[i])),
        None => Reply::empty(401),
    }
}
