# The requests scripts/test-examples.sh sends to this program, in order.
# Users 1 and 2 are members of project 1, and user 3 of none.
req GET /health
req GET /v1/in-place/projects/1
req GET /v1/projects/1
req GET /v1/projects/9
req PUT '/v1/projects/1/tasks/3/assignee?user=2' -H 'X-User: 1'
req PUT '/v1/projects/9/tasks/3/assignee?user=2' -H 'X-User: 1'
req PUT '/v1/projects/1/tasks/3/assignee?user=2' -H 'X-User: 3'
req PUT '/v1/projects/1/tasks/3/assignee?user=3' -H 'X-User: 1'
req PUT '/v1/projects/1/tasks/6/assignee?user=2' -H 'X-User: 1'
req PUT '/v1/projects/1/tasks/3/assignee?user=2'
