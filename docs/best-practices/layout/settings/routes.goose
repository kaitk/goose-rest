// The signed-in user's settings, under /settings.
namespace settings;

import std;
import http;
import rest;
import common.users.structs;
import settings.structs;

fn routes(cx, user: users::User) {
    if rest::on(cx, "GET", "") {
        rest::json(cx, 200, Settings { user: user.id, time_zone: "Europe/Tallinn" });
    } else {
        rest::otherwise(cx);
    }
}
