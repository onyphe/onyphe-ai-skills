---
type: regex
target: last_message
pattern: 'domain:\S+\s+OR\s'
match: not_contains
---

OQL has no OR keyword. `domain:a OR domain:b` fails with
`filter not allowed: ORdomain`.
