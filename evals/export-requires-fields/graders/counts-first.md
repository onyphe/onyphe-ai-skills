---
type: llm
target: trace
criteria: |
  Export streams everything that matches, with no ceiling to stop an
  over-broad query. The agent should establish the population size before
  exporting.

  Score 1.0 if it counts before exporting.
  Score 0.5 if it exports with a projection but no prior count.
  Score 0.0 if it exports with neither a count nor a projection.
focus: Did the agent scope with a count before an unbounded export?
---
