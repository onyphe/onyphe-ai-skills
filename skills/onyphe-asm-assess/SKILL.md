---
name: onyphe-asm-assess
description: >-
  Use when the user wants a prioritised attack-surface risk assessment of an
  inventory: "assess our attack surface," "what should we fix first," "risk report
  for this inventory," "which CVEs are exploited on our assets," "how has our
  exposure changed since the spring," "onyphe asm assess." Runs a multi-step
  analysis over riskscan and vulnscan with a 7-month trend and a findings table.
  Do NOT fire on a single Discovery query (see onyphe-asm), on building the
  inventory (see onyphe-asd-discover), or on hunting unknown infrastructure
  (see onyphe-hunt).
version: 1.2.0
---

# onyphe-asm-assess

From an `inventory.txt` to a ranked list of what to fix, with the evidence.

## Before starting

Confirm: the inventory file, who owns the assets (this is an assessment of the
user's own attack surface), the window (default **3M**, maximum useful **7M** for
riskscan), and whether they want the full pass or just the KEV/critical items.
A full pass is one Discovery call per tag per window (unlimited on Griffin View).

## Phases

**0. Validate.** `onyphe-inventory-check.sh inventory.txt`. Fix invalid lines
before anything else; a bad line yields unrelated documents, not an error.

**1. Baseline.** `onyphe-asm-count.sh riskscan inventory.txt <window>` with no tag:
how many documents and distinct assets ONYPHE holds for this inventory at all.
Report the **coverage**: inventory entries versus assets seen. Entries with no
asset are "no signal", not "safe".

**2. Risk tags.** Count per tag: `risk::exposeddatabase`, `risk::criticalcve`,
`risk::vpnserver`, `risk::sensitiveprotocol`, `risk::loginpage` and any others the
baseline shows. Rank by assets, not documents.

**3. CVEs.** riskscan already carries CVE data, so `tag:vulnerable` and `cve` can be read there together with the risk tags. Go to vulnscan for the **evidence** (the stored response behind a verdict) and for **negatives**: only vulnscan can say an asset was checked and passed. `onyphe-asm-count.sh vulnscan inventory.txt <window> vulnerable
vulnerableversion maybevulnerable maybevulnerableversion cisa::kev`. Count **both**
kinds: `vulnerable` is check-based (a test for that CVE found it) and
`vulnerableversion` is version-based (the detected version is on ONYPHE's list);
the second is about ten times larger. Report them separately, check-based first.
Pull `cve` for the positive set:
```bash
onyphe -discovery vulnscan 'inventory.txt -exists:cve -since:3M -fields:ip,port,hostname,cve,tag,seen_date'
```
Always add `-exists:cve` to a vulnscan Discovery call: most vulnscan documents are
negative or undecided verdicts with no CVE (5 592 604 of 1 938 348 687 carry one,
2026-10-16), and without it the result is mostly noise. A side effect: documents
tagged `unknownversion` normally carry no `cve`, so they drop out. Known-exploited
(`cisa::kev`) first, then count of CVEs per asset
(`cvecount`).

**4. Trend.** Repeat the phase 2 counts for 1M, 3M and 7M windows. A tag that is
present in 7M and absent in 1M was **fixed or stopped being observed**; the data
cannot tell those apart. A tag newly present in 1M is new exposure. Riskscan stops
at about seven months; say so rather than extrapolating.

**5. Context gate.** For each finding, check `hostname`/`organization` for shared
infrastructure the user cannot remediate. If an IP looks like emulation
(many services, banner mismatch), use `onyphe-honeypot` before reporting it.

**6. Report.** Use the findings template at
[findings-template.md](../onyphe-hunt/references/findings-template.md). Each finding:
asset, risk or CVE, first and last seen in the window, evidence command, and
confidence. Then a coverage statement.

## Rules this skill enforces

- **No signal is not "safe".** State the unscanned or unmatched inventory entries
  explicitly and never write "no vulnerabilities".
- **Assets, not documents.** Re-scans multiply documents.
- **Evidence comes from vulnscan.** riskscan's raw `data` is truncated after a period of time; cite vulnscan when a finding must be proven.
- **Distinguish verdicts.** Check-based beats version-based. `maybevulnerable`, `partialversion` and `unknownversion` are undecided, and `vulnerableversion` is an inference from the version, not a confirmed exposure.
- **Fixed versus unobserved is unknowable** from absence alone.
- **Say what the window was** on every number.

## Cross-references

- `onyphe-asm` — the single-query layer and its measured behaviour.
- `onyphe-asd-discover` — improve coverage by improving the inventory.
- `onyphe-timeline`, `onyphe-honeypot`, `onyphe-hunt` (findings template).
