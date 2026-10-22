// The application's entry: the program's types, and the routes through
// dispatch.goose. main.goose imports it to serve, and each test imports it as
// a package, `import app from "../../";`, as a test can't import main.goose.
import std;
import http;
import plod;
import dispatch;
import projects.structs;
import teams.structs;

// The worker state: what stands in for the database until Plod has
// database helpers.
struct App { projects: projects::Project[>..]&, teams: const teams::Team[:] }
