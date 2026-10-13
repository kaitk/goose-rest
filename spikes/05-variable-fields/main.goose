// Spike 05: can a JSON reader fill a struct's u8[] fields one key at a time,
// in the order the keys arrive? See README.md.
import std;
import json;

struct Project { id: i64, name: u8[], color: u8[] }

// A field can't be filled after construction, so the reader keeps each
// string as a slice, of the text or, for one with escapes, of scratch, and
// builds the struct once, after the last key. A repeated key rebinds its
// slice: the last one wins.
fn read_project(r: json::Reader&, scratch: u8[>..]&) -> Project {
    var id = 0;
    var name = r.text[..0];
    var color = r.text[..0];
    json::each_member(r) { key =>
        if key == "name" { name = json::read_string(r, scratch); }
        else if key == "color" { color = json::read_string(r, scratch); }
        else if key == "id" { id = json::read_int(r); }
        else { json::skip(r); }
    };
    return Project { id: id, name: name, color: color };
}

fn main() {
    var body: u8[>..] = [];
    body.append("""
        [{"color": "#ff0000", "id": 7, "name": "goose"},
         {"name": "duck", "id": 8},
         {"name": "a", "extra": [1, 2], "name": "swan", "id": 9}]
        """);
    var r = json::reader(body);
    var scratch: u8[>..] = [];
    var all: Project[>..] = [];
    json::each_element(r) { all.push(read_project(r, scratch)); };
    print(json::finish(r), " ", all.len);
    for p in all { print(p.id, " [", p.name, "] [", p.color, "]"); }
}
