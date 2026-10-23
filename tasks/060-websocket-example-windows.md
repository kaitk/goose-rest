# 060: The websocket example's echo on Windows

Status: todo

`scripts/test-examples.sh` fails `examples/websocket` on Windows under Git Bash: the
upgrade answers 101, but no frame comes back, where `expected.txt` has the echoed
`hello` and the Close (2026-10-23):

```diff
 GET /health 200 ok
 GET /ws 426 {"error":"upgrade_required"}
-WS /ws 101 ..hello....
+WS /ws 101
```

It failed in three runs on the goose-http `v0.5.8` pin and in one at `fef3e43`, before
it, and passes on Linux (WSL2). Whether the server or the client is at fault is
open. `requests.sh`'s `ws` sends the handshake, a masked text frame, and a Close in one
`printf` with octal escapes, through `curl -T - telnet://`; on Windows, either step may
not deliver the frame bytes as written.

## Acceptance criteria

- [ ] The failing side found: the bytes the server receives after the handshake,
      checked against what `printf` and curl send
- [ ] The example passes on Windows, by a fix in the server or in `requests.sh`, with
      the cause recorded here or in `docs/known-issues.md`
