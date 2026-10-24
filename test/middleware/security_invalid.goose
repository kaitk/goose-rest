import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
import plod from "../../";

fn main() {
    var options = plod::security_html();
    options.content_security_policy = "default-src 'self'\r\nX-Injected: yes";
    print("security headers reject CRLF during setup");
    plod::prepare_security_headers(options);
}
