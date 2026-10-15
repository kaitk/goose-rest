# 037: Data compiled into the binary

Status: todo, spike (asked for 2026-10-15)

Read-only data known at build time, such as holidays, a list of countries, or a catalog
shipped with a release, can be compiled in: `const` globals with compile-time
initializers are static data, read-only and shared between workers as they are (spec
§11.2). Each worker reads the one copy in the binary's read-only pages, with no copy at
spawn, no work at startup, and plain typed code. A record whose strings are slices
(`const u8[:]`) into static bytes holds each at its exact length, with no limited
array's capacity (task 027, case 1).

Whether that holds at size is the question: hundreds of thousands of struct literals may
be slow to compile, through Goose and then the C compiler, or large in the binary.

Not for the benchmark servers (2026-10-15): there every framework loads its data at
startup, the same way, so the comparison stays fair. Zig's comptime could compile data
in too, but none of the servers does.

## Questions

1. Does a `const` array of structs whose fields are integers and string slices count as
   static data in the pinned release, so a `thread_fn` reads it without a copy? A
   minimal program, and its generated C, show it.
2. Compile time and binary size for 1,000, 10,000, 100,000, and 200,000 records of a
   catalog-like struct, through `goose build` and the C compiler, against the same data
   loaded from a file at startup.
3. Idle RSS with 1, 2, and 4 workers, showing that the data is held once.
4. What writes the Goose file: a generator command (`goose-rest bake data.json --type
   app::Item -o data.goose`, from a JSON array and a schema type), or the program's own
   build step. Whether a generated schema type can hold it, since the generator writes
   strings as `u8[]` or limited arrays, not slices.

## Acceptance criteria

- [ ] Each question answered here, with the programs in `spikes/` and their recorded
      output, and every number with how it was measured
- [ ] A recommendation: build the generator command, document the pattern only, or
      neither, with the size up to which it's worth it
- [ ] If it's recommended, the tutorial's page 8 and task 035's part on laying out an
      application give it as the answer for data known at build time
