# The requests scripts/test-examples.sh sends to this example, in order.
json='Content-Type: application/json'
auth='Authorization: Bearer secret'
req GET /health
echo "GET / $(curl -s -o /dev/null -w '%{http_code} %{content_type}' "http://127.0.0.1:$port/")"
req GET /v1/status
req GET /v1/settings
req PUT /v1/settings -H "$json" -d '{"name": "porch", "brightness": 128, "interval_ms": 500}'
req PUT /v1/settings -H 'Authorization: Bearer wrong' -H "$json" -d '{"name": "porch", "brightness": 128, "interval_ms": 500}'
req PUT /v1/settings -H "$auth" -H "$json" -d '{"name": "porch", "brightness": 128, "interval_ms": 500}'
echo "LED brightness $(cat "$LED/brightness")"
req PUT /v1/settings -H "$auth" -H "$json" -d '{"name": "porch", "brightness": 300, "interval_ms": 500}'
req PUT /v1/settings -H "$auth" -H "$json" -d '{"name": "porch", "brightness": 10, "interval_ms": 50}'
req PUT /v1/settings -H "$auth" -H "$json" -d '{"name": "a name longer than thirty-two code points", "brightness": 10, "interval_ms": 500}'
req PUT /v1/settings -H "$auth" -H "$json" -d '{"name": "porch", "brightness": 10, "interval_ms": 500, "color": "red"}'
# Past putSettings' x-body-limit of 1 KB.
req PUT /v1/settings -H "$auth" -H "$json" -d "{\"name\": \"porch\", \"brightness\": 10, \"interval_ms\": 500$(printf '%1100s' '')}"
req GET /v1/settings
req GET /v1/status
# Firmware: 190,000 bytes of image, 253,336 in base64, within putFirmware's
# x-body-limit of 256 KB, and 400,000 bytes, past it.
yes goose | head -c 190000 >"$out/image.bin"
printf '{"version": "1.2.0", "image": "%s"}' "$(base64 <"$out/image.bin" | tr -d '\n')" >"$out/firmware.json"
req PUT /v1/firmware -H "$auth" -H "$json" --data-binary @"$out/firmware.json"
req PUT /v1/firmware -H "$auth" -H "$json" -d '{"version": "1.2.0", "image": "not base64!"}'
yes goose | head -c 400000 >"$out/image.bin"
printf '{"version": "1.3.0", "image": "%s"}' "$(base64 <"$out/image.bin" | tr -d '\n')" >"$out/firmware.json"
req PUT /v1/firmware -H "$auth" -H "$json" --data-binary @"$out/firmware.json"
req PUT /v1/firmware -H "$json" -d '{"version": "1.2.0", "image": "AAAA"}'
req POST /v1/firmware
req OPTIONS /v1/settings -H 'Origin: https://fleet.example' -H 'Access-Control-Request-Method: PUT'
req GET /v1/status -H 'Origin: https://evil.example'
req GET /nope
