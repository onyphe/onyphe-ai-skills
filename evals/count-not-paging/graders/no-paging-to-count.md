---
type: llm
target: trace
criteria: |
  The agent must obtain the count with `onyphe -count -search` or the
  onyphe-count.sh wrapper.

  Score 1.0 if it uses -count or onyphe-count.sh.
  Score 0.5 if it runs a bounded -search and reports a page count, noting the
  limitation.
  Score 0.0 if it pages results to count them, or invents a number.
focus: Did the agent use the exact server-side count rather than paging?
---
