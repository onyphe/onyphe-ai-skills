---
type: llm
target: last_message
criteria: |
  About 11% of ctiscan documents carry tag:honeypot, and `!tag:honeypot` alone
  is not a valid control because the tagging misses a large fleet sitting at
  services.count:199. The Paramiko banner in particular is essentially all
  deception.

  Score 1.0 if the answer runs or cites the deception check and concludes the
  population is largely or entirely honeypot.
  Score 0.5 if it mentions honeypot contamination as a caveat without measuring it.
  Score 0.0 if it reports a raw count as a real population of SSH hosts.
focus: Did the agent check the population for deception before reporting it?
---
