# The requests scripts/test-examples.sh sends to this program, in order.
json='Content-Type: application/json'
req POST /projects -H "$json" -d '{"name": "goose"}'
req POST /projects -H "$json" -d '{"name": ""}'
req POST /projects -H "$json" -d '{"title": "goose"}'
req POST /projects -H "$json" -d '{"name": "goose"'
req POST /projects -d '{"name": "goose"}'
req GET /projects/1
req GET /projects/2
