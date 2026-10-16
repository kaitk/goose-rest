// The entries' rules: typed input in, a result or an error out, no cx.
namespace entries;

import std;
import entries.structs;
import entries.errors;

// The entry that input creates, with id, or why it can't: it ends after it
// starts, and no later than now.
fn new_entry(input: CreateInput, id: i64, now: i64) -> Entry, Error {
    guard input.stopped > input.started else { return Entry { .. }, Error.EndsBeforeStart; }
    guard input.stopped <= now else { return Entry { .. }, Error.InFuture; }
    return Entry { id: id, project: input.project, started: input.started, stopped: input.stopped }, Error.None;
}
