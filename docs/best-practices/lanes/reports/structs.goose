// The reports' types, and how they're written as JSON.
namespace reports;

import std;

// The time recorded on a project.
struct Totals { project: i64 = 0, entries: i64 = 0, seconds: i64 = 0 }

fn format(out: u8[>..]&, t: const Totals&) {
    format(out, "{\"project\":", t.project, ",\"entries\":", t.entries, ",\"seconds\":", t.seconds, "}");
}
