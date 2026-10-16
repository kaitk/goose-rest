# Best practices

The [tutorial](../tutorial/README.md) shows what goose-rest can do, one mechanism at a
time, and often more than one way to do it. That freedom helps while you learn, and
starts to cost once an application grows. When a route, a rule, or a job could live in
any file and be called anything, every new piece of code is a small decision, and every
reader has to work out again how this particular application was put together.

This section expects you to know Goose, and what the tutorial teaches: workers that
serve many connections each, routes, extractors, and middleware, and above all its
pages on [work that waits](../tutorial/11-waiting.md), where a route asks another thread
and resumes in a case function. The pages here use those mechanisms without explaining
them again.

This section makes those decisions once. It's an opinionated guide to building an
application with goose-rest: where each piece of code goes, what it's called, and how
the pieces call each other. It's how goose-rest's authors build their own applications,
and the way they recommend. Nothing in goose-rest enforces it, and an application built
another way works just as well. What it gives up is a shape that others already know.

The shape is built from a few parts. *Domains* are folders, one for each part of the
product. *Routes* read a request and answer it, *rules* make the domain's decisions, and
*jobs* do the slow work, on *lanes*, threads of their own.
[Concepts and naming](concepts.md) lists every part, with what other frameworks call it.

That shared shape is the point. When every domain has the same files, every route reads
the request and asks for at most one job, and every wait is a step listed in one enum,
you find any piece of code without searching, and a file's name tells you what kind of
change a diff makes. You can reason about a piece of code from where it sits: a rule
does no I/O, a job is one transaction on a lane, and a route never blocks its worker. A
developer who knows these conventions reads your application as easily as their own,
and one who comes from Actix-web, Axum, Hono, or Spring recognizes most of it: handlers,
middleware, services, and repositories, under the names and with the differences that
Goose brings ([Concepts and naming](concepts.md)).

Each rule has a heading of its own, so that a review can link to it, and a reason, so
that you can tell when it applies, and when your application is the exception.

1. [Concepts and naming](concepts.md): each part of an application, its equivalents in
   other frameworks, and how it's named.
2. [Layout by domain](layout.md): a folder per domain, the same files in each, and
   `common/` for what several domains use.
3. [Routes and rules](routes-and-rules.md): a route handles HTTP, a rule decides, and
   a job does the slow work.
4. [Errors](errors.md): one shape, and each domain's codes in one place.
5. [Middleware and stacks](middleware.md): middleware named by a verb, a stack per
   audience, and each scope behind one stack.
6. [Lanes and jobs](lanes.md): a lane, a thread, for each kind of slow work, long CPU
   work off the workers, how many jobs a lane's box holds, and which work is refused
   under load.
7. [State](state.md): where data lives, by what it is.
8. [Testing](testing.md): small tests per domain, and scenarios over HTTP.

Every page draws its examples from one application, a time-tracking API whose domains,
routes, and data [Layout by domain](layout.md) describes. Each page's code is quoted
from a small program in the folder of the same name, a slice of that application, which
`scripts/test.sh` builds and sends requests to, as it does for the tutorial's programs.
