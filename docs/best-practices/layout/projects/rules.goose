// The projects' rules: typed input in, a result or an error out, no cx.
namespace projects;

import std;
import common.members.structs;
import projects.structs;
import projects.errors;

// The project input creates for member, with id, or why it can't.
fn new_project(input: CreateInput, member: members::Member, id: i64) -> Project, Error {
    guard input.name.len > 0 else { return Project { .. }, Error.NameRequired; }
    guard input.name.len <= 64 else { return Project { .. }, Error.NameTooLong; }
    return Project { id: id, organization: member.organization, name: input.name }, Error.None;
}
