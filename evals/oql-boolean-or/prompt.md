---
name: oql boolean or
tags: [correctness, oql]
plugins: ["../.."]
runs: 3
max_turns: 6
timeout_seconds: 180
allowed_tools: [Bash, Read]
---

Write an ONYPHE query that finds datascan documents for any of the domains revolut.com, revolut.codes or revolutlabs.com. Show me the query.

This skill does not run anything. Once the query is right, hand it to
`onyphe-search`.
