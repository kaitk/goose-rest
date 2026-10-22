// The entries' rules, called as plain functions. The clock is a parameter,
// so each case is the same on every run.
import std;
import http from "github.com/kaitk/goose-http@v0.5.1";
import rest from "../../../../../";
import app from "../../";

let NOW: i64 = 1767268800;

fn main() {
    fn tried(started: i64, stopped: i64) -> entries::Error {
        let e, err = entries::new_entry(entries::CreateInput { project: 1, started: started, stopped: stopped }, 1, NOW);
        return err;
    }
    print("an hour, ended: ", tried(NOW - 7200, NOW - 3600));
    print("ending at now: ", tried(NOW - 3600, NOW));
    print("ending before it starts: ", tried(NOW - 3600, NOW - 7200));
    print("ending in the future: ", tried(NOW - 3600, NOW + 1));
}
