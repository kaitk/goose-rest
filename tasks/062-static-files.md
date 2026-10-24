# 062: Static files, and whether a cache pays

Status: todo (2026-10-24). Where the time of a static file over TLS goes in
`plod::files`, and, if reading the disk is it, a file cache in goose-http that a
program chooses where it calls `plod::files`, bounded, and following the disk.

## Why

HttpArena scores static-h2 and static-h3 (task 047, "The pull request"). In the
results of 2026-10-23 (Plod `v0.5.4`, HttpArena's 64-core Threadripper), the entry's
static-h2 is about 350 of 1,000:

| Profile | Connections | Entry | CPU | Leader |
|---|---:|---:|---:|---:|
| static-h2 | 256 | 407,892 | 6,241% | swerver, about 1.1 M on average |
| static-h2 | 1,024 | 375,952 | 6,442% | |
| static-tls (reference only) | 1,024 | 437,637 | 6,491% | fib, 1,229,892 |

Both serve about 15 KB a response, the leaders' within 5%, so the gap isn't in what
is sent. At 6,300% CPU for 392 K requests a second, a request costs about 160 µs of
CPU; baseline-h2 costs about 2 µs (14.4 M at 3,000%). AES-GCM over 15 KB is a few
microseconds, so neither the bytes nor the cipher explain it on their own. static-h3
will be scored the same way once the entry runs it.

## What the rules allow

`site/content/docs/add-framework/implementation-rules/frameworks/standard.md` at
HttpArena's `d9438f6`, "Static files: the cache is the framework's, not the entry's":
an entry may serve from memory when the cache is the framework's own documented
static handler, and the cache follows the disk ("Replace a file and the next response
must carry the new bytes"). A cache assembled in the entry is out, as is a mapping
filled once and never checked. Choosing a file's `.br` or `.gz` copy off
`Accept-Encoding` is allowed for every entry.

## What `plod::files` does now

Per request, with goose-http `v0.5.9`'s `file.goose`:

- `http::open_precompressed` opens the file and reads its size and time, then opens
  the copy that `Accept-Encoding` weighs highest (`.br` under HttpArena's
  `br;q=1, gzip;q=0.8`), and closes the original: two opens and a close before a byte
  is read.
- Over TLS, the body is read in pieces of up to 64 KiB (`FILE_PIECE`) at each `MORE`,
  into a buffer of its own and then into the write buffer, and encrypted from there.
  `sendfile` (`direct`) runs only on plain TCP, for pieces from 64 KiB.
- The file is closed at the end. Nothing is kept between requests.

The 20 files are 1.16 MB together; the largest, `vendor.js`, is 300 KB, 67 KB as
`.br`.

## Steps

1. A/B, on any machine with Docker: static-h2's load (HttpArena's
   `scripts/lib/tools/h2load.sh` for static-h2: its URI list, `Accept-Encoding`, and
   streams) against the entry as it is, and against a throwaway build that serves the
   20 files' bytes from memory, on the same CPUs, interleaved. Not committed: the rule
   forbids that build as an entry. The ratio says whether opening and reading the
   files is the cost. The absolute numbers don't matter, so Docker Desktop is fine.
2. If it isn't, profile static-h2 on Linux (`perf record` on the server's workers),
   once a Linux machine is free (the desktop runs the h3 tuning as of 2026-10-24):
   the h2 framing and flow control, the copies, the `MORE` turns per file, and TLS
   records are the candidates. A cache wouldn't help then; record the cause here and
   the fix in goose-http.
3. If it is, design the cache, then build it in goose-http (a file cache is HTTP
   machinery) with a Plod form of `plod::files` that takes it:
   - The program chooses it where it calls `plod::files`; no field on `Cx` and no
     cost to a program that doesn't (AGENTS.md, "Keep changes small").
   - Bounded as a promise: a byte budget per worker, reserved when the worker starts,
     and a file past what's left isn't cached but served from disk as now. Workers
     share nothing, so each holds its own copy; say what that costs at 64 workers.
   - Follows the disk: each request checks the file's size, time, and inode with one
     `stat` before serving cached bytes, and reads it again where they changed. Say
     what that check costs against the two opens it replaces.
   - The `.br` and `.gz` copies are cached as files of their own, chosen as
     `open_precompressed` chooses them.
   - A test that replaces a file and gets the new bytes on the next request, and one
     that fills the budget.
4. Measure the entry's static-h2 and static-tls before and after, and baseline's peak
   RSS, which a cache must not raise for routes that don't use it.

## Acceptance criteria

- [ ] The A/B's ratio recorded here, with the machine and how it was run
- [ ] The cause named: the disk path, or what else, with the profile behind it
- [ ] If a cache: its design recorded in goose-http's `docs/decisions.md`, built, and
      tested for a replaced file and a full budget
- [ ] If a cache: the entry's static-h2 measured before and after, and the entry using
      it through Plod's documented call
