---
name: export carries a projection
tags: [correctness, cost]
plugins: ["../.."]
runs: 3
max_turns: 6
timeout_seconds: 180
allowed_tools: [Bash, Read]
---

Export every ONYPHE ctiscan document from the last week where the certificate issuer CN is "Major Cobalt Strike", and save it to data/cs.ndjson.
