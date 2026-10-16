---
name: onyphe-summary
description: Use when the user has one IP, domain or hostname and wants everything ONYPHE holds on it, or wants to triage a batch of indicators — e.g. "onyphe summary," "look this IP up on onyphe," "what does onyphe know about," "onyphe profile this host," "triage these IPs with onyphe," "onyphe bulk lookup," or "is this IP interesting per onyphe." Wraps `-summary`, `-bulk-summary`, `-simple` and `-bulk-simple`. Note the Summary API returns datascan-model documents and never ctiscan/ctiurl — for a threat-hunting baseline, pair it with a direct ctiscan search. Not for criteria-based search (see onyphe-search) or full population pulls (see onyphe-export).
version: 1.0.0
---

# onyphe-summary

## When to use

Use this skill when the starting point is a specific identifier rather than a
query — an IP, a domain, a hostname — or when a list of them needs fast triage
before deciding which deserve real attention. Typical asks:

- "what does onyphe have on 203.0.113.10"
- "triage these 200 IPs from the feed"
- "which of these domains has anything interesting"

For "find me everything matching this condition", use `onyphe-search`.

## The one thing to know first

**The Summary API does not return ctiscan or ctiurl.** Verified 2026-09-25
across several hosts: `-summary ip` returned `datascan`, `riskscan`, `ip`,
`pastries`, `resolver`, `sniffer`, `topsite` and `whois` documents, and never
ctiscan — including for a host that had 9 ctiscan documents in the same week.

Two consequences, both load-bearing for hunting work:

1. Summary output is in the **datascan dialect** (`data`, `cpe`, `port`,
   `status`, `device.class`, `app.http.*`), not the ctiscan one. Do not carry
   field names from a summary straight into a ctiscan query — see `onyphe-oql`.
2. A summary is **not a ctiscan baseline**. Pair it with a direct search:

```bash
onyphe -summary ip 203.0.113.10
onyphe -size 100 -maxpage 1 -search 'category:ctiscan ip.dest:203.0.113.10 -weekago:1'
```

Reporting only the summary and calling it "what ONYPHE knows" understates the
host by an entire data model.

## Invocation

| Mode | Use |
|---|---|
| `onyphe -summary ip\|domain\|hostname '<value>'` | Everything across categories for one identifier |
| `onyphe -bulk-summary ip\|domain\|hostname input.txt` | The same, streamed, one identifier per line |
| `onyphe -simple <category> '<value>'` | One category only |
| `onyphe -simple-best <category> '<value>'` | Best single match — `whois`, `threatlist`, `geoloc`, `inetnum` only |
| `onyphe -bulk-simple <category> ip.txt` | One category, streamed, over a file of IPs |

Summary covers roughly the **last 30 days** and returns 10 or 100 results per
category depending on the endpoint.

## Common patterns

```bash
# Single identifier, then narrowed to what actually matters
onyphe -summary ip 203.0.113.10 | opp 'fields @category,ip,port,protocol,tag'

# Which categories does this host appear in at all
onyphe -summary ip 203.0.113.10 | jq -r '."@category"' | sort | uniq -c | sort -rn

# Batch triage: one call, streamed, surfacing only the flagged hosts
onyphe -bulk-summary ip feed-ips.txt \
  | opp 'exists tag | uniq ip,tag'

# Single category when that is all you need
onyphe -simple threatlist 203.0.113.10
onyphe -simple-best whois 203.0.113.10
```

## Interpreting results

NDJSON, mixed categories in one stream, each line carrying its own
`@category`. Split on that field before reading anything — the field names mean
different things per category, and a `port` from `datascan` is not a `tcp.dest`
from `ctiscan`.

Triage signals worth acting on, in rough order of usefulness:

- **`tag`** — the richest one. `risk::*` entries carry a stated reason;
  `malware`, `botnet`, `c2`, `compromised`, `phishing`, `webshell` are direct
  hits; `honeypot`, `scanner`, `tor`, `vpn`, `proxy` mean *reclassify*, not
  *escalate*.
- **`category:threatlist`** — presence on a public feed, with the feed named.
  A feed hit is a claim by a third party, not a verdict.
- **`category:riskscan`** — ONYPHE's own risky-configuration detections.
- **`category:vulnscan`** — CVE detections, with a verdict tag. Note the
  difference between a check-based verdict and a version-based one; the latter
  is a fallback and carries less weight.

Every one of these is a prioritisation signal, not a conclusion. An IP that
returns nothing is an IP that was not scanned recently or not indexed — not an
IP that is clean.

## Error handling

| Symptom | Cause and fix |
|---|---|
| Empty result for a live host | Summary is a ~30-day window and not every host is scanned in every pass. Try a direct ctiscan search with a wider window. |
| `-simple ctiscan` rejected | There is no Simple endpoint for ctiscan. Use `-search category:ctiscan ip.dest:...`. |
| `-simple-best` rejected for a category | Only `whois`, `threatlist`, `geoloc` and `inetnum` have a "best" form. |
| `API rate limit reached` (error 1001) | Roughly 1 request/second across the account. For a list, use the bulk form — one call, not N. |

## Caveats

- **Simple and Bulk Simple are deprecated** and slated for removal in a future
  API version. Prefer `-summary` for multi-category context and `-search` for
  anything specific; reach for `-simple` only where it is the single cheapest
  way to answer a narrow question.
- Use the **bulk** form for lists. A loop of single calls costs the same credits
  and runs straight into the per-second limit.
- Summary is capped per category, so it is a sample of a busy host, not its
  complete record. For completeness on one category, query that category
  directly.
- Geolocation is approximate and wrong in the usual ways for CDN, VPN and
  satellite ranges.
- `-summary` and `-bulk-summary` accept only `ip`, `domain` and `hostname`.

## Cross-references

- **onyphe-search** — the ctiscan/ctiurl half that Summary does not cover.
- **onyphe-oql** — the datascan/ctiscan field translation, needed the moment a summary result becomes a hunting query.
- **onyphe-opp** — filtering and projecting the mixed-category stream.
- **onyphe-hunt** — the full methodology this is normally step 2 of.
- **onyphe-honeypot** — before a `tag` or feed hit becomes an assertion.
- **onyphe-asm** — riskscan and vulnscan for a whole inventory, not one asset.
