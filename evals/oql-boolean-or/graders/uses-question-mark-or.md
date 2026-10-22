---
type: regex
target: last_message
pattern: '\?domain:example\.com\s+\?domain:example\.net\s+\?domain:example\.org'
match: contains
---

OQL expresses OR as a `?` prefix on every term, e.g. `( ?domain:a ?domain:b )`.
