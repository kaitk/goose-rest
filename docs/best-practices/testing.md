# Testing

An application's tests follow Goose's own convention
([Tests](../decisions.md#tests)), laid out by domain as the code is:

- **Small tests, by domain.** Each test is a small program in `test/<domain>/`, such as
  `test/projects/`, that prints what it checks; that output is compared with its golden file. It calls
  the domain's rules as plain functions, and its routes, middleware, and stacks through
  `rest::serve_one` ([Testing](../reference.md#testing)).
- **Scenarios over HTTP.** A folder per scenario under `test/` runs the real program, its
  workers and service threads, and compares its answers with a golden file.
- **`// error:` fixtures** for what must not compile, such as a route given the wrong
  state type.

A test that needs a socket, a thread, or more than one domain is a scenario. Every other
test is a small test in its domain's folder, and most tests should be.

The examples for this page aren't written yet. [Testing the application](../tutorial/16-testing.md)
shows the calls the small tests make.

---

[Best practices](README.md) · Previous: [Naming](naming.md)
