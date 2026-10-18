# The requests scripts/test-examples.sh sends to this program, in order.
json='Content-Type: application/json'
req POST /projects -H "$json" -d '{"name": "goose", "color": "#00ff00"}'
req POST /projects -H "$json" -d '{"name": "gander"}'
req POST /projects -H "$json" -d '{"name": "goose", "color": "#00ff00ff"}'
# "#00ffé0", as UTF-8 through stdin: Git Bash would pass an é in an argument
# to a Windows curl in the ANSI code page.
printf '{"name": "goose", "color": "#00ff\303\2510"}' | req POST /projects -H "$json" --data-binary @-
req POST /projects -H "$json" -d '{"name": "goose", "owner": 1}'
req POST /projects -H "$json" -d '{}'
req POST /projects -d '{"name": "goose"}'
req GET /projects/1
req GET /projects/2
