---
type: regex
target: last_message
pattern: '(^|[\s"''(])data:'
match: not_contains
---

`data:` is the datascan name. Using it under category:ctiscan silently returns 0.
