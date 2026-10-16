# Best practices

The [tutorial](../tutorial/README.md) teaches goose-rest's mechanisms one at a time, and
shows the options each one has. This section gives one way to put them together into an
application that grows: where each piece of code goes, and what it's called. It's the
way goose-rest's authors build their own applications, and the approach they recommend. You
don't have to follow it, and goose-rest doesn't check it. Its value is that one
convention, followed everywhere, lets a reader find any piece of code without looking.

Each rule has a heading of its own, so that a review can link to it, and a reason, so
that a reader can tell when it applies.

1. [Layout by domain](layout.md): a folder per domain, the same files in each, and
   `common/` for what several domains use.
2. [Routes and rules](routes-and-rules.md): a route extracts, calls one rule or service,
   and answers; a rule takes typed input and has no `cx`.
3. [Middleware and stacks](middleware.md): middleware named by a verb, a stack per
   audience, and each scope behind one stack.
4. [State](state.md): where data lives, by what it is, and where its types are declared.
5. [Errors](errors.md): one shape, and each domain's codes in one place.
6. [Naming](naming.md): every name an application gives, in one table.
7. [Testing](testing.md): small tests per domain, and scenarios over HTTP.

Each page's code is quoted from a small program in the folder of the same name, which
`scripts/test.sh` builds and sends requests to, as it does for the tutorial's programs.
