// What the tests share. Each test's root imports test/ as the package expect:
//
//   import expect from "../";
//
// which also reaches test/gen/'s generated modules, as
// `import expect.gen.api_gen;`.
namespace expect;

import std;

// Fails the test unless got is want, and shows both.
fn same(got: const u8[:], want: const u8[:]) {
    if got != want {
        print("got:\n", got, "\nwant:\n", want);
        assert(false);
    }
}

// same, naming what it compares.
fn same(got: const u8[:], want: const u8[:], what: const u8[:]) {
    if got != want {
        print(what, ":\ngot:\n", got, "\nwant:\n", want);
        assert(false);
    }
}

// A whole answer's body and status line.
fn body_of(out: const u8[:]) -> const u8[:] { out[find(out, "\r\n\r\n") + 4..] }

fn status_of(out: const u8[:]) -> const u8[:] { out[..find(out, "\r\n")] }

// A request without a body, with Host and then fields.
fn request(method: const u8[:], target: const u8[:], fields: const u8[:] = "") -> u8[>..] {
    str(method, " ", target, " HTTP/1.1\r\nHost: x\r\n", fields, "\r\n")
}
