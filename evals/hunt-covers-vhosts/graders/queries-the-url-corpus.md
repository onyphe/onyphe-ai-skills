---
type: regex
target: transcript
pattern: '(category:ctiurl|category:ctiscan,ctiurl|http\.hostname)'
match: contains
---

A hunt on a shared-hosting IP that never touches the URL-level corpus cannot see
the vhosts, which is the entire question being asked.
