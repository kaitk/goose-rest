# Best practices

As an application grows, its organization matters more. The [tutorial](../tutorial/README.md)
shows one mechanism at a time, often in more than one way. This section picks one: where
each piece of code goes, what it's called, and how the pieces call each other. Without
that, every reader has to work out again how this particular application was put
together.

It's an opinionated guide to building an application with goose-rest, the way its
authors build their own. Nothing in goose-rest enforces it, and an application built
another way works just as well; it only gives up a shape that others already know.

An application laid out this way has a few main parts. *Domains* are folders, one for
each part of the product. *Routes* read requests and answer them, *rules* make the
domain's decisions, and *jobs* do slow work on *lanes*, threads of their own.
[Concepts and naming](concepts.md) lists each part and what other frameworks call it.

When every domain has the same files, every route asks for at most one job, and every
wait is a step in one enum, you find code without searching, and a file's name tells
you what kind of change a diff makes. Where code sits tells you what it may do: a rule
does no I/O, so a test can call it as a plain function; a job is one transaction on a
lane; and a route never blocks its worker. A developer from Actix-web or Spring
recognizes its handlers, middleware, services, and repositories, under other names and
with the differences Goose brings ([Concepts and naming](concepts.md)).

This section assumes you know Goose, and its pages don't explain again what the tutorial
teaches: workers that serve many connections each, routes, extractors, and middleware.
Ideally you've also read [work that waits](../tutorial/11-waiting.md);
[Lanes and jobs](lanes.md) repeats what this section needs from it.

Each rule has its own heading so a review can link to it, and a reason, so you can tell
when it applies and when your application is the exception.

1. [Concepts and naming](concepts.md): each part of an application, its equivalents in
   other frameworks, and how it's named.
2. [Layout by domain](layout.md): a folder per domain, the same files in each, and
   `common/` for what several domains use.
3. [Routes and rules](routes-and-rules.md): a route handles HTTP, a rule decides, and
   a job does the slow work.
4. [Errors](errors.md): one shape, and each domain's codes in one place.
5. [Middleware and stacks](middleware.md): middleware named by a verb, a stack per
   audience, and each scope behind one stack.
6. [Lanes and jobs](lanes.md): a lane for each kind of slow work, long CPU work kept
   off the workers, how many jobs a lane's box holds, which work is refused under
   load, lanes of several threads, and a placement file per kind of machine, whose
   grammar and platforms are goose-http's
   [tuning guide](https://github.com/kaitk/goose-http/blob/main/docs/tuning.md).
7. [State](state.md): where data lives, by what it is.
8. [Testing](testing.md): small tests per domain, and scenarios over HTTP.

Every page draws its examples from one time-tracking API.
[Layout by domain](layout.md) describes its domains, routes, and data. Each page quotes a
small program, in the folder of the same name, that covers part of that API.
`scripts/test.sh` builds these programs and sends them requests, as it does for the
tutorial's programs.
