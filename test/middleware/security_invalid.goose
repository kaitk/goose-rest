import std;
import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";
import rest from "../../";

fn main() {
    var options = rest::security_html();
    options.content_security_policy = "default-src 'self'\r\nX-Injected: yes";
    print("security headers reject CRLF during setup");
    rest::prepare_security_headers(options);
}
