---
name: counting uses -count
tags: [correctness, cost]
plugins: ["../.."]
runs: 3
max_turns: 6
timeout_seconds: 180
allowed_tools: [Bash, Read]
---

How many ONYPHE ctiscan documents were tagged as honeypots yesterday?
