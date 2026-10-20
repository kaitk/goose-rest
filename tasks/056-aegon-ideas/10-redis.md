# 10: A Redis client in Goose

Status: todo. After task 052 settles goose-postgres's shape.

Aegon's Redis client speaks RESP3 without hiredis, which matches the rule that the
package is Goose with no C. A goose-redis would follow goose-postgres: the protocol
without I/O, a blocking facade for lane jobs, and pipelining as a library call.

Aegon's pages (`data/redis/client`, `data/redis/advanced`, `data/redis/topologies`,
read 2026-10-20) list what comes after the core:

- Strings, hashes, lists, sets, sorted sets, and expiry commands
- A raw command returning a RESP value
- Lua through `EVALSHA`, falling back to `EVAL` on `NOSCRIPT`
- `MULTI` and `EXEC`
- Pub/sub on a connection of its own, with patterns
- Streams with consumer groups
- Locks checked by token on release and extension
- Sentinel: the master found by `SENTINEL get-master-addr-by-name`
- Cluster: CRC16 slots with `{hash tag}` support, slots refreshed on `MOVED` and
  `ASK`, and a pipeline split by shard and put back in order

Aegon keeps a pool per worker thread. In goose-rest that's either connections on a
lane's thread, as task 052 decides for Postgres, or goose-http's outbound connections
on each worker (its task 053).

A cache backend is where picking an implementation from configuration first comes up,
such as Redis in production and the lane store of subtask 09 in development. Aegon
registers a different object behind one interface. Goose has a generic parameter, fixed
at build time, or an ADT of the backends, with a `match` at each call. Which one
programs use is open.

## Acceptance criteria

- [ ] A repository plan: its README's status table and first tasks
- [ ] The decision on where its connections are driven recorded, as task 052 does for
      Postgres
- [ ] How a program picks between cache backends, generic parameter or ADT, decided
      with an example
