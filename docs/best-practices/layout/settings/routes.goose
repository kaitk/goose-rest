// The signed-in user's settings, under /settings.
namespace settings;

import std;
import http;
import plod;
import common.users.structs;
import settings.structs;

fn routes(cx, user: users::User) {
    plod::get(cx, "") { plod::json(cx, 200, Settings { user: user.id, time_zone: "Europe/Tallinn" }); };
}
