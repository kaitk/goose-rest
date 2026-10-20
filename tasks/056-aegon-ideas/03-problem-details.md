# 03: RFC 9457 problem details as a preset

Status: done

Errors are JSON with a snake_case `error` code, and a program can write another shape.
A preset writes RFC 9457 problem details through the existing `rest::error_body`
overload for a program's request state. A second overload, `rest::error_type`, selects
`application/problem+json`. Both resolve at compile time. The default stays unchanged.

Agreed reading (2026-10-20): `rest::problem_body(body, status, code, detail, at)` writes
`type: "about:blank"`, `title` from the response's reason phrase, numeric `status`,
`detail` when not empty, and the byte offset `at` as an extension when not negative.
It accepts `code` to match the existing hook's inputs but doesn't write it.

`instance` is omitted: RFC 9457 makes it optional, and the hook has no path, nor does
the runtime retain one for delayed errors. A program wanting `instance` can write its
own `error_body` overload using a value in its request state. No shared struct gains
a field.

## Acceptance criteria

- [x] `rest::problem_body` in `runtime.goose`, covering every error in
      `docs/reference.md`'s table, `rest::fail` included, through the existing hook
- [x] `rest::error_type(st)` defaults to `http::JSON` and can select problem+json for
      the same request state, without changing the `error_body` signature
- [x] A golden test per field, one for an error with `detail` and `at`, and one for a
      delayed error's problem shape and media type
- [x] `docs/reference.md`, section 5, shows both overloads as the switch
- [x] `scripts/test.sh` passes
- [x] Costs nothing when off: compare the default `write_error` C from `goose build`
      at `origin/main` and on this branch, normalizing generated names and inert
      aliases/scopes, and cross-check identical optimized machine code

## Validation

After rebasing onto `b8ce74c`, `scripts/test.sh` passed: 102 programs at `-O0` and
`-O2`, 8 compile-error fixtures, generator goldens, TypeScript 7.0.2, examples,
tutorial and best-practices programs, documentation excerpts, spikes, and inlining
checks. The default hook returns a slice of `http::JSON`, avoiding a fixed-array copy.

### Default error path

The agreed check (2026-10-20) uses `test/runtime/route.goose`, which answers failures
through the default `error_body` and `write_error`. The baseline is `origin/main` at
`b8ce74c`, repeated after rebasing without conflicts. Both builds use Goose
`f114b5a`, the pin in `scripts/goose.sh`, on an Apple M1 Pro, macOS 26.3.1,
Darwin 25.3.0, with Apple clang 21.0.0.

Commands, from the repository root; `GOOSE` can name an existing build of the pin:

```sh
export GOOSE=${GOOSE:-$(scripts/goose.sh)}
check_dir=build/problem-details/c-check-rebased
mkdir -p "$check_dir/origin" "$check_dir/current"
git archive b8ce74c | tar -x -C "$check_dir/origin"
git archive HEAD | tar -x -C "$check_dir/current"
"$GOOSE" build -O2 --standalone -o "$check_dir/default-origin" \
    "$check_dir/origin/test/runtime/route.goose" >"$check_dir/origin-build.log" 2>&1
"$GOOSE" build -O2 --standalone -o "$check_dir/default-current" \
    "$check_dir/current/test/runtime/route.goose" >"$check_dir/current-build.log" 2>&1
for version in origin current; do
    c_file=$(awk '/^wrote / { sub(/^wrote /, ""); sub(/ \([0-9]+ bytes\)$/, ""); print }' \
        "$check_dir/$version-build.log")
    cc -O2 -S "$c_file" -o "$check_dir/$version.s"
    cc -c "$check_dir/$version.s" -o "$check_dir/$version.o"
    xcrun llvm-objdump --disassemble-symbols=_rest_write_error_g4 \
        "$check_dir/$version.o" >"$check_dir/$version-object.txt"
done
python3 tasks/056-aegon-ideas/problem-c.py "$check_dir"
```

Result: `write_error`'s C is identical after the agreed normalization. The comparison
renames temporary variables and labels, puts uninitialized local declarations in
canonical order, and removes unused state-pointer aliases and the constant-header
lexical scope. The branch has one extra unused alias and one extra scope from
inlining `error_type`; it adds no executed operation. Normalized C SHA-256:
`92a11f28ec2c74f06babef80dd80fecd0eeaec39eb670a1250730d42d18028c0`.

The optimized assembly is byte for byte identical, including registers, operands,
branches, and labels. The unlinked object code is also identical: 3,004 bytes,
SHA-256 `3b26671e2f0fffd70467e690276fd88f8ef29613bc74101345811062d626b116`.
Objects are compared before linking so different source paths don't change linked
string addresses. This is the evidence for no default-path cost.

The `bench/stack.sh` instruction counts wait for a target-platform constant in Goose
([finding](../../docs/goose-findings.md#goose-code-has-no-target-platform-constant)).
Its server still fails to link on macOS because of glibc's `mallopt`; no portability
fix is applied. The harness includes `GET /api/items/0` on tier A, a 404 from
`rest::fail`, for that later measurement.
