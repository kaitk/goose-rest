# The requests scripts/test-examples.sh sends to this program, in order.
# rows N prints N records, about 14 bytes each.
rows() { awk -v n="$1" 'BEGIN { for (i = 1; i <= n; i++) printf "Task %d,ada\n", i }'; }
csv='Content-Type: text/csv'
req GET /health
printf 'Write the docs,ada\nShip it,grace\n' | req POST /v1/projects/1/tasks/import -H "$csv" --data-binary @-
# About 13 KB, past the 8 KB read buffer: gathered, then imported.
rows 1000 | req POST /v1/projects/1/tasks/import -H "$csv" --data-binary @-
# About 300 KB, past the route's 256 KB.
rows 20000 | req POST /v1/projects/1/tasks/import -H "$csv" --data-binary @-
# Refused before the body is read.
rows 1000 | req POST /v1/projects/9/tasks/import -H "$csv" --data-binary @-
rows 1000 | req POST /v1/projects/1/tasks/import -H 'Content-Type: application/json' --data-binary @-
# A bad record adds no task.
printf 'Fine,ada\n"Broken"x,ada\n' | req POST /v1/projects/1/tasks/import -H "$csv" --data-binary @-
printf 'Fine,ada\nNo assignee\n' | req POST /v1/projects/1/tasks/import -H "$csv" --data-binary @-
req GET /v1/projects/1/tasks
req GET /v1/projects/2/tasks
