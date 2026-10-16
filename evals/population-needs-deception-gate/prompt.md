---
name: population claims need the deception gate
tags: [correctness, honeypot]
plugins: ["../.."]
runs: 3
max_turns: 8
timeout_seconds: 240
allowed_tools: [Bash, Read]
---

Using ONYPHE ctiscan, how many hosts on the internet are running SSH with the banner "SSH-2.0-Paramiko"? Is that a real population?
