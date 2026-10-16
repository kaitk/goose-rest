# Naming

Two rules guide naming throughout an application, and the table below applies them to
each kind of name.

## A name doesn't repeat its domain

Each domain is a namespace ([Layout by domain](layout.md#a-domain-is-a-namespace)), so
a name inside it leaves the domain out: `projects::CreateInput`, not
`projects::ProjectCreateInput`, and `projects::routes`, not `projects::project_routes`.

The namespace already says it at every call from outside, and inside the domain the
shorter name is unambiguous.

## Each layer has a shape of its own

A route is a bare verb, a service job a verb and a noun, and a data-access function a
query verb and a noun. A call chain then shows which layer each call is in:

```text
projects::create  ->  create_project  ->  find_project, insert_project
   route              service job          data access
```

The noun in a service job's or a query's name is the exception to the rule above: it
distinguishes a job or a query from the route that calls it, and distinguishes the
queries of a job that touches several entities from each other.

## The names

| Kind | Shape | Examples |
|---|---|---|
| Domain folder, and its namespace | The entity it holds, plural, or else the area it covers | `projects/`, `entries`; `timer`, `auth`, `settings` |
| File in a domain or in `common/` | Its kind ([the files](layout.md#the-same-files-in-every-domain)) | `structs.goose`, `errors.goose`, `rules.goose`, `routes.goose`, `service.goose` |
| Stack | Its audience, singular, and `_routes` | `public_routes`, `user_routes`, `member_routes` |
| Middleware | A verb | `authenticate`, `resolve_organization`, `limit_rate` |
| Block parameter | What it's given | `user`, `member` |
| A domain's entry | `routes` | `projects::routes(cx, member)` |
| Route | The operation's verb | `list`, `create`, `archive`, `add_team` |
| Rule | What it returns | `new_project`, `archived`, `readable` |
| Service job | A verb and a noun | `create_project`, `archive_project` |
| Data access | A query verb and a noun | `find_project`, `list_projects`, `insert_project` |
| Struct | A noun, and `<Verb>Input` for what a client sends | `Project`, `CreateInput`, `UpdateInput` |
| Domain error | `Error`, a variant per refusal | `Error.NotFound`, `Error.NameTaken` |
| Error code | The entity, then what went wrong, in snake_case | `project_not_found`, `project_name_taken` |
| `Waiting` variant | The domain and the operation | `Waiting.ProjectCreate` |
| Case function | What it does with each variant | `check` for an `Error`, `resume` for a `Waiting` |

A domain's data access gets a file of its own once goose-rest has database helpers. Its
functions' names follow the table already.

---

[Best practices](README.md) · Previous: [Errors](errors.md) · Next: [Testing](testing.md)
