// The projects' rules: typed input in, a result or an error out, no cx.
namespace projects;

import std;
import projects.errors;

// Why project id can't be read, or Error.None.
fn readable(id: i64) -> Error {
    guard id == 1 || id == 2 else { return Error.NotFound; }
    return Error.None;
}

// Why project id can't be removed, or Error.None.
fn removable(id: i64) -> Error {
    guard id == 1 || id == 2 else { return Error.NotFound; }
    guard id != 2 else { return Error.Archived; }
    return Error.None;
}
