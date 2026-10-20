-- bench/stack.sh's requests, 16 pipelined copies of one: json, tier F's POST
-- /json with its 159-byte object; item, tier M's GET /api/items/42 with its
-- bearer token, Accept-Encoding, and Origin; or post, tier M's POST
-- /api/items/7 with its 51-byte body, token, and Origin.
-- error is GET /api/items/0, answered with 404 item_not_found on tier A.
--
--   wrk -t 8 -c 256 -d 10 -s bench/stack/pipelined.lua http://127.0.0.1:PORT -- json|item|post|error

local token = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    .. "eyJzdWIiOiI0MiIsImV4cCI6MTc5MDAwMDAwMH0." .. string.rep("x", 70)
local origin = "https://app.example"
local object = '{"id":12345,"name":"goose \\"rest\\"","active":true,"score":98.5,'
    .. '"tags":["fast","small","typed"],"owner":{"id":7,"login":"octo"},"note":null,"items":[1,2,3,4,5]}'
local req

function init(args)
    local one
    if args[1] == "json" then
        one = wrk.format("POST", "/json", { ["Content-Type"] = "application/json" }, object)
    elseif args[1] == "item" then
        one = wrk.format("GET", "/api/items/42", { ["Authorization"] = token,
            ["Accept-Encoding"] = "br;q=1, gzip;q=0.8", ["Origin"] = origin })
    elseif args[1] == "post" then
        one = wrk.format("POST", "/api/items/7", { ["Content-Type"] = "application/json",
            ["Authorization"] = token, ["Origin"] = origin }, '{"name":"bench-updated","price":250,"quantity":10}')
    elseif args[1] == "error" then
        one = wrk.format("GET", "/api/items/0")
    else
        error("pipelined: the request is json, item, post, or error")
    end
    req = string.rep(one, 16)
end

function request()
    return req
end
