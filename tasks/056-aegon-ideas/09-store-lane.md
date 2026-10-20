# 09: An in-process store on a lane

Status: todo

Aegon's MemStore ([its guide](https://udaykhare09.github.io/Aegon/guide/data/memory/memstore),
read 2026-10-20) is a key-value store that one thread owns, with no lock on the map.
Workers post a request and wait for the reply without blocking their loop, which in
Aegon is an `eventfd` read on the worker's ring. It's the cache for a single node, for
development, and for tests, and a drop-in for Redis behind the same cache interface.

That is a goose-rest lane, which already does the hard part: a job goes to the lane's
thread through its box, and the worker resumes the route when the reply comes
(`docs/reference.md`, "Lanes"). The map lives on the lane's thread, so it needs no lock,
and only flat values cross between threads, as Goose requires. So the store is a module
over lanes, not a mechanism of its own.

What it provides, after Aegon's API:

- `get`, `set` with an optional TTL, `del`, `mget`, `del_many`, and `incr` (created at
  1), as one job enum, with a `resume` helper per call so a route reads the reply as a
  value
- A fixed maximum entry count, evicting the least recently used entry; reads and writes
  both count as a use
- Expiry both lazy (an expired entry is a miss when read) and active (a sweep on the
  lane's thread between jobs, at an interval), as Redis does
- Hit and miss counters, and the entry count

What differs from Aegon, because of Goose:

- No general heap. The map and the LRU list are arrays, with entries linked by index,
  and values in a growing byte array or in slots of a fixed size. The memory is fixed
  when the lane opens, which keeps goose-rest's memory lead.
- Each call is a wait in the route. In Aegon a `co_await` hides it. Here a route that
  reads the cache and then answers has a `resume` step, as any lane call has
  (best practices, "Continuing a route when the reply comes"). The helpers keep a cache
  read to one `rest::ask` and one `resume`.
- A lane job, such as database work (task 052), runs on another thread and can't wait
  through the route. It needs a blocking call to the store's lane. Whether `http::Lane`
  allows a thread to ask another lane and block on the reply is open.
- For data read on every request and rarely written, such as feature flags, a copy per
  worker, updated by a message, avoids the hop altogether. Measure both.

The interface is shared with Redis (subtask 10), so a program swaps one for the other
in configuration. Whether that's a generic parameter or an ADT is subtask 10's question.

## Acceptance criteria

- [ ] A module with the calls above, LRU at a fixed entry count, and both kinds of expiry
- [ ] Tested through `rest::serve_one`, expiry and eviction included
- [ ] A blocking call for lane jobs, or the reason it can't be built yet
- [ ] A cache read's cost on tier A measured: the hop to the lane against a copy per worker
- [ ] A best-practices page: sessions, rate limits, and a cache in front of a query
