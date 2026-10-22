// error: rest needs the package hash
// A program that imports rest.websocket must declare goose-hash, for the
// handshake's SHA-1, in its root file.
import std;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../";
import rest.websocket;

fn main() {}
