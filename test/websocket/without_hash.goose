// error: rest needs the package hash
// A program that imports rest.websocket must declare goose-hash, for the
// handshake's SHA-1, in its root file.
import std;
import http from "github.com/kaitk/goose-http@v0.5.0";
import rest from "../../";
import rest.websocket;

fn main() {}
