---
type: llm
focus: whether the answer treats a long-window resolver zero as evidence of absence
criteria: |
  1.0 - The answer rejects the user's inference and gives a correct reason: that
        `reverse` is one of the resolver fields that stops being searchable past
        about seven months, so the zero is an artefact of the filter rather than
        evidence about the host. Credit equally an answer that instead (or also)
        raises the Griffin View licence gate, or that runs/recommends the paired
        control count (the same query without the field filter) to tell the two
        kinds of zero apart. Suggesting `type:reverse` as the depth-safe
        substitute is a strong signal.
  0.5 - The answer is cautious about the zero and declines to confirm "nothing
        ever resolved there", but does not identify why (no stripped field, no
        licence gate, no control count).
  0.0 - The answer accepts the premise and confirms that nothing resolved to the
        address, or otherwise reports the zero as a finding about the host.
---

A zero from a stripped field is indistinguishable from a real absence unless the
reader knows the field boundary exists. This is the single most likely way for
the new resolver phase to produce a confident wrong answer.
