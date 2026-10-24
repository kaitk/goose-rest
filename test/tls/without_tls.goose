// error: plod needs the package tls
// A program that imports plod.tls must declare goose-tls in its root file.
import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";
import plod.tls;

fn main() {}
