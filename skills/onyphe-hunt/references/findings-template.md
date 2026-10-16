# Findings template

Copy to `analysis/findings.md` at the **start** of a hunt. Every section is
populated or explicitly marked N/A before the hunt is called complete.

---

```markdown
# Hunt: <target or cluster name>

- Started: YYYY-MM-DD
- Updated: YYYY-MM-DD
- Status: in progress | complete | abandoned
- Licence / view: <from onyphe-preflight.sh>
- Windows used: <e.g. -weekago:1 throughout, -dayago:N for the series>
- Credits spent: <running total>

## Summary

Two or three sentences. What was investigated, what was concluded, and the
confidence. If the answer is "no linked infrastructure found", that goes here
as the conclusion, not as a failure.

## Host profile

| Attribute | Value |
|---|---|
| IP | |
| ASN / organisation | |
| Country | |
| Subnet | |
| Reverse DNS | |
| services.count | |
| Open ports | |
| Tags | |

## Services observed

| Port | Protocol | Device class | Product | TLS | First seen | Last seen |
|---|---|---|---|---|---|---|

## Indicator triage

Population as measured, with the window. Rarity bands per onyphe-pivot.

### Usable (population 1-25)

| Field | Value | Population | Window | Survived deception gate |
|---|---|---:|---|---|

### Rejected as too broad (over ~25)

| Field | Value | Population | Why rejected |
|---|---|---:|---|

### Rejected as provider fleet artefact

| Field | Value | Population outside the ASN | Conclusion |
|---|---|---:|---|

A value with 0 population outside the host's own ASN is locked to that provider
and carries no attribution weight.

## Deception gate

Four-count results for every indicator that reached a pivot.

| Indicator | total | tagged | mp199 | other | hpish% | Verdict |
|---|---:|---:|---:|---:|---:|---|

Residual profiling, for any low-hpish candidate with a large `other`:

| Indicator | Top organisations in residual | Top ports | Reading |
|---|---|---|---|

## Pivot results

| Indicator | Documents | Distinct hosts | Distinct ASNs | File |
|---|---:|---:|---:|---|

### Cluster membership

Two independent indicators required. List which two, per host.

| Host | Indicator 1 | Indicator 2 | Confidence |
|---|---|---|---|

## Timeline

| Bucket | Count |
|---|---:|

- Retention edge found at: <the oldest bucket that returned non-zero>
- Crossed to datascan: yes / no / not available on this licence
- Simultaneous-change clusters observed: <bucket, and which signals moved together>

## Zero-result queries

Kept deliberately. A zero is only meaningful once all four exclusions are made.

| Query | Dialect checked | Field -exists: | Window widened | Category authorised | Reading |
|---|---|---|---|---|---|

## Assessment

What the evidence supports, and at what confidence. State the counts with their
windows. Distinguish "distinct hosts" from "documents" explicitly.

## What was not excluded

The section that makes the rest trustworthy. Anything skipped, shortened or
assumed:

- [ ] Residual profiled by hand for every low-hpish candidate?
- [ ] Two independent indicators for every cluster member?
- [ ] Retention edge probed before reading any decline?
- [ ] Provider-fleet test run on every attribute claimed as operator-specific?
- [ ] Window as wide as the question needed, or capped by licence?

## Open questions

- [ ]

## Data files

| File | What it is | Query that produced it |
|---|---|---|

## Progress log

| Date | Action | Credits |
|---|---|---:|
```
