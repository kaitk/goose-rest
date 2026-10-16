// The reports' rules: the sums, which take CPU over a long period's entries
// rather than wait.
namespace reports;

import std;
import entries.structs;
import reports.structs;

// The time recorded on project in all.
fn totals(all: const entries::Entry[:], project: i64) -> Totals {
    var t = Totals { project: project, .. };
    for e in all {
        if e.project == project {
            t.entries++;
            t.seconds += e.stopped - e.started;
        }
    }
    return t;
}
