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
- Resolver authorised: yes / no (CTI-only — phase 2c skipped, not zero)
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
| Names in passive DNS (window) | |
| Distinct vhosts on this IP | |
| services.count | |
| Open ports | |
| Tags | |

## Services observed

| Port | Protocol | Device class | Product | TLS | First seen | Last seen |
|---|---|---|---|---|---|---|

## Vhost profile

From phase 2b. A zero here means no name ONYPHE knows points at this IP — a
statement about the vhost target list, not about the host.

| Vhost | Port | TLS | HTTP code | Title | First seen | Last seen |
|---|---|---|---|---|---|---|

## Passive DNS

From phase 2c. Griffin View only; mark N/A with the reason otherwise.

| Name | type | source | First seen | Last seen | Docs | Names on IP | Verdict |
|---|---|---|---|---|---:|---:|---|

Gate results (top 5 names by document count; record the cap):

| Name | G0 mechanical | G1 any | G2 elsewhere | G3 names/IP | G4 template | Verdict |
|---|---|---:|---:|---:|---:|---|

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

| Indicator | Base | total | tagged | mp199 | other | hpish% | Verdict |
|---|---|---:|---:|---:|---:|---:|---|

One row per base. Quote each against its own corpus: `tag:honeypot` is 11.3% of
ctiscan and 0.015% of ctiurl, so the same hpish% means different things. A ctiurl
total of 0 is exit 2 — inconclusive, not clean.

Residual profiling, for any low-hpish candidate with a large `other`:

| Indicator | Top organisations in residual | Top ports | Reading |
|---|---|---|---|

## Pivot results

| Indicator | Documents | Distinct hosts | Distinct host:port:vhost | Category split (ctiscan/ctiurl) | Distinct ASNs | File |
|---|---:|---:|---:|---|---:|---|

The ratio of hosts to host:port:vhost is what separates shared hosting from an
operator estate.

### Cluster membership

Two independent indicators required. List which two, per host.

| Host | Indicator 1 | Indicator 2 | Confidence |
|---|---|---|---|

## Timeline

| Bucket | Count |
|---|---:|

- Retention edge found at: <the oldest bucket that returned non-zero>
- Crossed to: datascan (7M) / resolver (12M) / neither / not available on this licence
- Resolver retention edge: <oldest non-zero -monthago: bucket>
- Fidelity cliff: did any resolver query past 7 months filter on a stripped field? yes / no
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
- [ ] ctiurl queried as well as ctiscan, or the reason it was not recorded?
- [ ] Passive-DNS names checked for mechanical PTR and shared hosting?
- [ ] Every resolver query past 7 months checked against the stripped-field list?

## Open questions

- [ ]

## Data files

| File | What it is | Query that produced it |
|---|---|---|

## Progress log

| Date | Action | Credits |
|---|---|---:|
```
