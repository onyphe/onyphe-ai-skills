---
name: opp routing
tags: [routing, opp]
plugins: ["../.."]
runs: 3
max_turns: 5
timeout_seconds: 120
allowed_tools: [Bash, Read]
---

I have a saved ONYPHE ndjson file. Count the distinct IPs in it without re-querying the API.
