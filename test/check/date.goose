// plod::is_date, format date's check.
import std;
import http from "github.com/kaitk/goose-http@v0.5.10";
import plod from "../../";

fn main() {
    for s in ["2026-10-13", "2024-02-29", "2000-02-29", "0001-01-01", "2026-12-31"] {
        if !plod::is_date(s) { print("is_date refused ", s); assert(false); }
    }
    for s in ["2026-10-1", "2026-13-01", "2026-00-10", "2026-04-31", "2023-02-29", "1900-02-29",
              "2026/10/13", "2026-10-13T", "20261013", "abcd-10-13", ""] {
        if plod::is_date(s) { print("is_date took ", s); assert(false); }
    }
    print("plod::is_date: ok");
}
