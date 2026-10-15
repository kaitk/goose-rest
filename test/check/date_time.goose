// rest::is_date_time, format date-time's check.
import std;
import http from "github.com/kaitk/goose-http@v0.3.3";
import rest from "../../";

fn main() {
    for s in ["2026-10-13T18:28:00Z", "2026-10-13t18:28:00z", "2026-10-13T18:28:00.123456Z",
              "2026-10-13T23:59:60+02:00", "2026-10-13T00:00:00-11:30"] {
        if !rest::is_date_time(s) { print("is_date_time refused ", s); assert(false); }
    }
    for s in ["2026-10-13T18:28:00", "2026-10-13 18:28:00Z", "2026-10-13T24:00:00Z",
              "2026-10-13T18:60:00Z", "2026-10-13T18:28:61Z", "2026-10-13T18:28:00.Z",
              "2026-10-13T18:28:00+0200", "2026-10-13T18:28:00+02:00x", "2026-02-30T00:00:00Z"] {
        if rest::is_date_time(s) { print("is_date_time took ", s); assert(false); }
    }
    print("rest::is_date_time: ok");
}
