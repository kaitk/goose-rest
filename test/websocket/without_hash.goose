// error: plod needs the package hash
// A program that imports plod.websocket must declare goose-hash, for the
// handshake's SHA-1, in its root file.
import std;
import http from "github.com/kaitk/goose-http@v0.5.11";
import plod from "../../";
import plod.websocket;

fn main() {}
