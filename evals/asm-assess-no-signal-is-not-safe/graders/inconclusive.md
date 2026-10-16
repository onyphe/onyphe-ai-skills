---
type: llm
target: last_message
criteria: |
  No result from a vulnscan Discovery query is not evidence of safety: assets may
  not have been scanned in the window, unknownversion/maybevulnerable verdicts are
  undecided, the window may be short, and the inventory may be malformed or
  incomplete.

  Score 1.0 if the answer refuses to conclude "no vulnerabilities", names at least
  two of those reasons, and suggests checking coverage or widening the window.
  Score 0.5 if it hedges but still leans towards "safe".
  Score 0.0 if it says the user can report no vulnerabilities.
focus: Did the agent treat an empty result as inconclusive rather than safe?
---
