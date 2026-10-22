// error: rest needs the package tls
// A program that imports rest.tls must declare goose-tls in its root file.
import std;
import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";
import rest from "../../";
import rest.tls;

fn main() {}
