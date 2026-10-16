---
type: regex
target: last_message
pattern: 'app\.data\.text'
match: contains
---

The ctiscan full-text field is `app.data.text`. A datascan-style `data:` under
`category:ctiscan` returns 0 with no error, which is indistinguishable from a
genuine absence.
