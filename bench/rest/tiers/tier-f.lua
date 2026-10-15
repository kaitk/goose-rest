-- wrk's requests for tier F,one route per run, as the
-- bun-http-framework-benchmark sends them: GET /, GET /id/1?name=bun, or POST
-- /json with a 159-byte object. Unpipelined.
--
--   wrk -t 8 -c 256 -d 15 -s bench/rest/tiers/tier-f.lua http://127.0.0.1:PORT -- root|id|json

local body = '{"id":12345,"name":"goose \\"rest\\"","active":true,"score":98.5,'
    .. '"tags":["fast","small","typed"],"owner":{"id":7,"login":"octo"},"note":null,"items":[1,2,3,4,5]}'
local req

function init(args)
    local route = args[1] or "root"
    if route == "root" then
        req = wrk.format("GET", "/")
    elseif route == "id" then
        req = wrk.format("GET", "/id/1?name=bun")
    elseif route == "json" then
        req = wrk.format("POST", "/json", { ["Content-Type"] = "application/json" }, body)
    else
        error("tier-f: the route is root, id, or json")
    end
end

function request()
    return req
end

function done(summary, latency, requests)
    if summary.errors.status > 0 then
        io.write("tier-f: ", summary.errors.status, " responses not 2xx\n")
    end
end
