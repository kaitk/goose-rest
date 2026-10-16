# The requests scripts/test-examples.sh sends to this program, in order.
req GET /health
# The writer creates an entry; the rule refuses one that ends before it
# starts, or in the future.
req POST /entries -d 'project=1&started=1767250800&stopped=1767254400'
req POST /entries -d 'project=1&started=1767254400&stopped=1767250800'
req POST /entries -d 'project=1&started=1767250800&stopped=4102444800'
req GET /reports/projects/1
# A report that takes half a second holds the reports' reader; two more wait
# in its box's two slots, and their clients give up (curl prints 000).
req GET '/reports/projects/1?ms=500' -m 0.05
req GET /reports/projects/1 -m 0.05
req GET /reports/projects/1 -m 0.05
# The box is full: 503 at once, while the writer still answers.
req GET /reports/projects/1
req POST /entries -d 'project=2&started=1767268800&stopped=1767270600'
sleep 1
# The hasher checks the password, then the writer opens the session.
req POST /auth/session -d 'email=ada@example.com&password=goose'
req POST /auth/session -d 'email=ada@example.com&password=gander'
req POST /auth/session -d 'email=bob@example.com&password=goose'
