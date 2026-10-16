// What the tests share. Each test imports test/ as the package expect:
//
//   import expect from "../";
namespace expect;

import std;

// A request's bytes: a form body, when there is one, with its length.
fn request(method: const u8[:], target: const u8[:], form: const u8[:] = "") -> u8[>..] {
    if form.len == 0 { return str(method, " ", target, " HTTP/1.1\r\n\r\n"); }
    return str(method, " ", target, " HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\n",
               "Content-Length: ", form.len, "\r\n\r\n", form);
}

// An answer as a test prints it: its status code and its body.
fn shown(out: const u8[:]) -> u8[>..] {
    let head = find(out, "\r\n\r\n");
    return str(out[9..12], " ", out[head + 4..]);
}
