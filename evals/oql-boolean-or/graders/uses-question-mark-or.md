---
type: regex
target: last_message
pattern: '\?domain:revolut\.com\s+\?domain:revolut\.codes\s+\?domain:revolutlabs\.com'
match: contains
---

OQL expresses OR as a `?` prefix on every term, e.g. `( ?domain:a ?domain:b )`.
