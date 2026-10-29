---
name: hunt separates vhosts from the IP that hosts them
tags: [methodology, ctiurl, vhost]
plugins: ["../.."]
runs: 3
max_turns: 6
timeout_seconds: 180
allowed_tools: [Bash, Read]
---

Run an ONYPHE hunt on 203.0.113.10. It looks like a shared hosting box — I want
to know which infrastructure actually belongs to the actor I am tracking.
