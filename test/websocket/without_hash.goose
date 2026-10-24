// error: plod needs the package hash
// A program that imports plod.websocket must declare goose-hash, for the
// handshake's SHA-1, in its root file.
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";
import plod.websocket;

fn main() {}
