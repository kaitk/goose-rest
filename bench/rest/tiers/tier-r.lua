-- wrk's requests for tier R (task 010): every route of github.txt, the
-- GitHub API's 203, in a fixed shuffled order that each thread starts at a
-- different place in, each parameter's value its name and the route's number,
-- as check.py requests them. Unpipelined; writes carry an empty body.
--
--   wrk -t 8 -c 256 -d 15 -s bench/rest/tiers/tier-r.lua http://127.0.0.1:PORT -- bench/rest/tiers/github.txt

local thread_id = 0
local reqs = {}
local at = 1

function setup(thread)
    thread_id = thread_id + 1
    thread:set("id", thread_id)
end

function init(args)
    local n = 0
    for line in io.lines(args[1]) do
        n = n + 1
        local method, pattern = line:match("^(%u+) (%S+)$")
        local path = pattern:gsub(":([%w_]+)", function(name) return name .. n end)
        local headers = {}
        local body = nil
        if method == "POST" or method == "PUT" or method == "PATCH" then
            headers["Content-Length"] = "0"
            body = ""
        end
        reqs[n] = wrk.format(method, path, headers, body)
    end
    -- The same shuffle in every thread, from a fixed seed.
    math.randomseed(203)
    for i = n, 2, -1 do
        local j = math.random(i)
        reqs[i], reqs[j] = reqs[j], reqs[i]
    end
    at = (id * 37) % n + 1
end

function request()
    local r = reqs[at]
    at = at % #reqs + 1
    return r
end

function done(summary, latency, requests)
    if summary.errors.status > 0 then
        io.write("tier-r: ", summary.errors.status, " responses not 2xx\n")
    end
end
