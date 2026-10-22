// The teams' routes, under /organization/teams.
namespace teams;

import std;
import http;
import plod;
import common.members.structs;
import teams.structs;

fn routes(cx, member: members::Member) {
    plod::get(cx, "") { list(cx, member); };
}

fn list(cx, member: members::Member) {
    var mine: Team[>..] = [];
    for t in cx.app.teams {
        if t.organization == member.organization { mine.push(t); }
    }
    plod::json(cx, 200, mine);
}
