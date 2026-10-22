// rest::format_fields, a JSON object from a struct's fields: each field type
// it writes, a nested struct through its own format overload, and an enum
// through the program's.
import std;
import http from "github.com/kaitk/goose-http@v0.5.4";
import rest from "../../";

enum Status { Active, Archived }

fn format(out: u8[>..]&, s: Status) {
    out.append(if s == Status.Active { "\"active\"" } else { "\"archived\"" });
}

struct Owner { name: u8[], admin: bool }

fn format(out: u8[>..]&, o: const Owner&) { rest::format_fields(out, o); }

struct Nothing { }

fn format(out: u8[>..]&, n: const Nothing&) { rest::format_fields(out, n); }

struct Project {
    id: i64,
    small: i32,
    big: u64,
    score: f64,
    ratio: f32,
    public: bool,
    name: u8[..256],
    code: u8[4],
    note: const u8[:],
    status: Status,
    owner: Owner,
    tags: u8[..16][],
    nums: i64[],
    owners: Owner[],
    empty: Nothing,
    missing: i64? = null,
    present: i64? = null,
}

fn main() {
    let seven: i64 = 7;
    let p = Project { id: 1, small: -2, big: 18446744073709551615, score: 0.1, ratio: 0.5, public: true,
                      name: "wild \"goose\"", code: "abcd", note: "line\nbreak",
                      status: Status.Archived, owner: Owner { name: "kai", admin: false },
                      tags: ["a", "b"], nums: [], owners: [Owner { name: "x", admin: true }],
                      empty: Nothing { }, present: seven };
    var out: u8[>..] = [];
    rest::format_fields(out, p);
    print(out);
}
