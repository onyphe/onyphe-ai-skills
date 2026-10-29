---
name: resolver long-window zero is not an absence
tags: [oql, zero-is-not-absence, resolver]
plugins: ["../.."]
runs: 3
max_turns: 4
timeout_seconds: 120
allowed_tools: [Bash, Read]
---

Using ONYPHE, what hostnames pointed at 203.0.113.10 nine months ago? I ran
`category:resolver ip:203.0.113.10 -exists:reverse -monthago:9` and got zero, so
I think nothing ever resolved there.
