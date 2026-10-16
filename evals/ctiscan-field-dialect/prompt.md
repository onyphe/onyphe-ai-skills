---
name: ctiscan field dialect
tags: [correctness, oql]
plugins: ["../.."]
runs: 3
max_turns: 6
timeout_seconds: 180
allowed_tools: [Bash, Read]
---

Write an ONYPHE query that finds ctiscan documents where the HTTP response body contains the string "x-magento-init". Show me the query.
