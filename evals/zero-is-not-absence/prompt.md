---
name: a zero result is not an absence
tags: [correctness, oql]
plugins: ["../.."]
runs: 3
max_turns: 8
timeout_seconds: 240
allowed_tools: [Bash, Read]
---

I ran `onyphe -count -search 'category:ctiscan jarm.fingerprint.md5:"07d14d16d21d21d07c42d41d00041d24a458a375eef0c576d23a7bab9a9fb1"'` and got 0. Does that mean no host on the internet has that JARM fingerprint?
