// The projects' rules: typed input in, a result or an error out, no cx.
namespace projects;

import std;
import projects.structs;
import projects.errors;

// The project that input creates, with id, or why it can't.
fn new_project(input: CreateInput, id: i64) -> Project, Error {
    guard input.name.len > 0 else { return Project { .. }, Error.NameRequired; }
    guard input.name.len <= 64 else { return Project { .. }, Error.NameTooLong; }
    return Project { id: id, name: input.name, archived: false }, Error.None;
}

// p archived, or why it can't be.
fn archived(p: Project) -> Project, Error {
    guard !p.archived else { return p, Error.AlreadyArchived; }
    var q = p;
    q.archived = true;
    return q, Error.None;
}
