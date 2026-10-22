// error: rest needs the package tls
// A program that imports rest.tls must declare goose-tls in its root file.
import std;
import http from "github.com/kaitk/goose-http@v0.5.4";
import rest from "../../";
import rest.tls;

fn main() {}
