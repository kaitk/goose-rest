# The requests scripts/test-examples.sh sends to this program, in order.
json='Content-Type: application/json'
req POST /projects -H "$json" -d '{"name": "goose", "color": "#00ff00"}'
req POST /projects -H "$json" -d '{"name": "gander"}'
req POST /projects -H "$json" -d '{"name": "goose", "color": "#00ff00ff"}'
req POST /projects -H "$json" -d '{"name": "goose", "color": "#00ffé0"}'
req POST /projects -H "$json" -d '{"name": "goose", "owner": 1}'
req POST /projects -H "$json" -d '{}'
req POST /projects -d '{"name": "goose"}'
req GET /projects/1
req GET /projects/2
