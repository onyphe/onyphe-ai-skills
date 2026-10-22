---
name: onyphe-asm
description: Use when the user wants to check an asset inventory against ONYPHE risk and vulnerability data: run the Discovery API on an inventory.txt, find exposed databases, login pages, sensitive protocols or CVEs on their own assets, or see how a risk changed over the last months. Wraps `onyphe -discovery riskscan|vulnscan`. Trigger phrases include "onyphe discovery," "check my inventory," "risks on our assets," "CVEs on our assets," "riskscan," "vulnscan," "exposed on our attack surface," and "inventory.txt." Not for building the inventory (see onyphe-asd-discover), the prioritised multi-step assessment (see onyphe-asm-assess), or hunting outside a known inventory (see onyphe-search).
version: 1.2.0
---

# onyphe-asm

> **Fields follow the datascan model.** `riskscan` and `vulnscan` documents use
> `ip`, `port`, `tag`, `cve`, `seen_date` and `hostname`, not the ctiscan names
> (`ip.dest`, `services.port`). A ctiscan field here returns 0 with no error.

## When to use

You have an `inventory.txt` and want to know which of those assets ONYPHE sees
carrying a risk or a known vulnerability, optionally over a time window.

- "which of our assets expose a database"
- "any CISA KEV CVEs on this inventory in the last three months"
- "did login pages appear on our assets since June"

## The two categories

- **riskscan** — risky configurations (`risk::*` tags) **and the same CVE
  detections as vulnscan**. Derived from ctiscan data, so it keeps the broadest and
  deepest scan coverage, and holds **history back about seven months**:
  `-monthago:7` returns documents, `-monthago:8` returns 0 (measured 2026-10-16).
  It is positive-only, and its raw response (`data`) is **truncated after a period
  of time**, so old documents keep their tags and CVEs but not the evidence.
- **vulnscan** — the same CVE data, plus what riskscan leaves out: **negative
  results** (`notvulnerable`, `notvulnerableversion`) and the **full stored response**
  used to assert each verdict. Use it to prove a verdict, to show an asset was
  checked and passed, and for history beyond seven months (`-monthago:12` still
  returns documents). It carries a `cve` array and a verdict tag; the full set is in
  [riskscan-vulnscan.md](../onyphe-oql/references/riskscan-vulnscan.md#vulnscan-verdict-tags).

| Need | Use |
|---|---|
| Which assets have a CVE or a risk, with one query | `riskscan` (CVEs and `risk::*` together) |
| Evidence: the response behind a verdict | `vulnscan` |
| "Was it checked and found not vulnerable?" | `vulnscan` (riskscan has no negatives) |
| Trend over the last seven months | `riskscan` |
| History older than seven months | `vulnscan` |

Field model, tags and counts: [riskscan-vulnscan.md](../onyphe-oql/references/riskscan-vulnscan.md).

## Invocation

```bash
# 1. Validate. A malformed line is not an error: it returns unrelated documents.
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-inventory-check.sh" inventory.txt

# 2. Latest state, projected
onyphe -discovery riskscan 'inventory.txt tag:risk::exposeddatabase -fields:ip,port,hostname,tag,seen_date'

# 3. A window
onyphe -discovery riskscan 'inventory.txt tag:risk::exposeddatabase -since:3M -fields:ip,port,tag,seen_date'

# 3b. vulnscan: always add -exists:cve, so only records carrying a CVE come back
onyphe -discovery vulnscan 'inventory.txt -exists:cve -since:3M -fields:ip,port,hostname,cve,tag,seen_date'

# 4. Which tags fire, as documents AND distinct assets
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-asm-count.sh" riskscan inventory.txt 3M risk::exposeddatabase risk::loginpage
```

The second argument is one quoted string: the inventory path, then OQL. Behaviour
measured on 2026-10-16:

- Each inventory line becomes a query, `category:riskscan domain:"example.com" <your OQL>`
  (visible in each result's `trackquery`). Your trailing OQL is **ANDed** into every
  line, so one filter applies to the whole inventory.
- **No `-since:`** returns the latest state per asset. **`-since:Nd|M`** returns every
  scan in the window: 57 documents for 6 assets over seven months on a small test
  inventory. Count assets, not documents.
- **`-fields:` works** inside `-discovery` and cuts the transfer to almost nothing.
- **vulnscan: always add `-exists:cve`.** Only 5 592 604 of 1 938 348 687 vulnscan
  documents carry a `cve` (`onyphe -count -search 'category:vulnscan -exists:cve'`,
  2026-10-16); the rest are negative or undecided verdicts. Documents tagged
  `unknownversion` (no version found) normally have no `cve`, so this filter excludes them: it answers
  "which assets have a CVE recorded", not "which assets could not be checked".
- Blank lines and `#` comments in the file are ignored.
- An `ip:"…"` line returns documents only if ONYPHE holds riskscan for that IP.

## Interpreting results

- **Zero is not "clean".** Not scanned recently, not indexed, a tag filter that was
  too narrow, a window that was too short, and a genuinely clean asset all return 0.
  Report it as "no signal found", and say which window and tags were tried.
- **A document is a scan, not an asset.** Deduplicate on `ip:port` and report
  both numbers.
- **vulnscan verdicts come in two kinds, and carry different weight.**
  *Check-based* (`vulnerable`, `notvulnerable`, `maybevulnerable`) come from an active,
  non-intrusive test for that CVE and are the preferred evidence. *Version-based*
  (`vulnerableversion`, `notvulnerableversion`, `maybevulnerableversion`,
  `partialversion`, `unknownversion`, `version`) are the fallback when no check exists:
  the detected product version is matched against ONYPHE's CVE list. `vulnerableversion`
  is the **bulk** of the CVE-bearing records (4 925 037 against 438 847 for `vulnerable`,
  2026-10-16), so a query for `tag:vulnerable` alone misses most of them. Report which
  kind each finding is. `maybevulnerable`, `unknownversion` and `partialversion` are
  undecided, not "not vulnerable". `cisa::kev` marks known-exploited CVEs.
- **Shared infrastructure.** A hit on an IP that hosts someone else's content (CDN,
  shared hosting, a vendor-run service) may not be the user's to fix. Check
  `hostname` before reporting.

## Error handling

| Symptom | Cause and fix |
|---|---|
| Thousands of unrelated documents | A line in the inventory did not parse. Run `onyphe-inventory-check.sh`. |
| `-since:` older than ~7 months, riskscan | 0 or no change: past retention. Use vulnscan for older context. |
| 0 with a ctiscan field name | Wrong data model for this category. Translate with the datascan map. |

## Caveats

- Cost: one call per command, unlimited on Griffin View licences; on a metered
  licence, treat each tag as a call.
- Prefer a short window and a tag filter, then widen.
- ONYPHE data is passive observation of the internet. It tells you what ONYPHE saw
  and when, not the current state of the asset.

## Cross-references

- `onyphe-asm-assess` — the full prioritised assessment.
- `onyphe-asd-discover` — build the inventory first.
- `onyphe-timeline` — how a single asset changed over time.
- `onyphe-oql` — query language and field model.
