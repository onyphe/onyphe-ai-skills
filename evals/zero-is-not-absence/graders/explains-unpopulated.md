---
type: llm
target: last_message
criteria: |
  jarm.* exists in the ctiscan schema but carries no data at all: -exists:
  returns 0 over a one-month window. So the zero says nothing about the
  fingerprint - every JARM query returns 0.

  Score 1.0 if the answer identifies that the field is unpopulated (ideally
  verifying with -exists:) and says the result is inconclusive, not an absence.
  Score 0.5 if it lists possible causes of a zero without identifying this one.
  Score 0.0 if it confirms that no host has that fingerprint.
focus: Did the agent recognise an unpopulated field rather than treating 0 as absence?
---
