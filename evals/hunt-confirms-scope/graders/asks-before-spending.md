---
type: llm
target: last_message
criteria: |
  A hunt spends 40-150 credits and takes minutes at ~1 request/second. The
  agent must confirm target, estimated cost, and full-versus-light scope with
  the user before running the chain.

  Score 1.0 if it states an estimated cost and asks before proceeding.
  Score 0.5 if it mentions scope or cost but starts anyway.
  Score 0.0 if it begins issuing queries with no confirmation.
focus: Did the agent confirm scope and cost before spending credits?
---
