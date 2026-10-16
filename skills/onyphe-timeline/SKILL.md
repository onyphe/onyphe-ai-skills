---
name: onyphe-timeline
description: Use when the user wants to know how something changed over time in ONYPHE — e.g. "onyphe timeline," "when did this appear," "has this host changed," "track this cluster over time," "onyphe historical," "is this growing or shrinking," or "what did this look like last month." Builds a time series by re-querying per time bucket, since ONYPHE has no change-event endpoint. Handles the ctiscan retention cliff and the licence-dependent crossover to datascan. Not for current state (see onyphe-search or onyphe-summary).
version: 1.0.0
---

# onyphe-timeline

## When to use

Use this skill for questions about change rather than state: when something
first appeared, whether a cluster is growing, whether a host looks the same as it
did a month ago.

## How temporal analysis works here

**There is no change-event or history endpoint.** Nothing returns a typed diff
stream for an asset. A timeline is built by running the same query once per time
bucket and comparing the results yourself.

```bash
for n in 0 1 2 3 4 5 6; do
  printf '%s\t' "$n"
  "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
    "category:ctiscan cert.issuer.cn:\"Major Cobalt Strike\" -dayago:$n"
done
```

One credit per bucket. The time functions select **whole buckets**, not rolling
windows — `-dayago:1` is all of yesterday, `-weekago:1` is Monday to Sunday of
last week. Mixing bucket sizes in one series produces a meaningless chart.

For content rather than counts, pull each bucket and compare:

```bash
for n in 0 1 2; do
  "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-export.sh" \
    "category:ctiscan ip.dest:203.0.113.10 -weekago:$n" \
    tcp.dest,app.protocol,cert.fingerprint.md5,component.product,tag \
    "data/host-w$n.ndjson"
done
diff <(jq -S . data/host-w1.ndjson) <(jq -S . data/host-w0.ndjson)
```

## The retention cliff

This is the failure mode that matters. ctiscan history is short, and past the
edge the query returns **0 — which looks exactly like "it went away"**.

Measured 2026-09-25, `category:ctiscan app.device:c2`:

| Window | Result |
|---|---|
| `-monthago:0` | 85 164 |
| `-monthago:1` | 25 511 |
| `-monthago:2` | **0** |
| `-monthago:3` and older | **0** |

The C2 population did not collapse to zero two months ago. The data is simply
not retained. The same probe against datascan on the same day:

| Window | `category:datascan device.class:c2` |
|---|---|
| `-monthago:0` | 45 947 |
| `-monthago:3` | 7 696 |
| `-monthago:6` | 4 040 |

**Always check your own retention before reading a declining series as a real
decline.** Run the query at increasing depth until it returns 0, and treat the
last non-zero bucket as the edge of the evidence, not the edge of the activity.

Nominal retention by category: ctiscan ~1 month; datascan, datashot and riskscan
7 months; most others 12 months; ctl, domain, hostname and ip 48 months. CTI-only
editions cap ctiscan far shorter still — 7 days, 14 days or 30 days depending on
the edition.

## Crossing to datascan for depth

When the window needed exceeds ctiscan's retention, datascan is the only way
further back — **and only if the licence includes it.**

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-preflight.sh" datascan
```

| Preflight result | What to do |
|---|---|
| `datascan` present (Griffin View) | Cross over, translate the fields, and say so in the output. |
| `datascan` absent (CTI-only: Catfish, Sealion, Shark) | **Stop at ctiscan's edge.** Report the window you could actually cover. Do not return an empty long-window result as if it were an answer. |

Crossing over is a change of data model, not just a category swap:

```bash
# ctiscan, recent
category:ctiscan app.device:c2 tcp.dest:443 -weekago:1

# datascan, for depth - different field names entirely
category:datascan device.class:c2 port:443 -monthago:4
```

See `onyphe-oql`'s translation reference. Two things to state explicitly
whenever a series crosses the seam:

- **The models differ.** Counts on either side are not strictly comparable; they
  are different scanners with different coverage and cadence.
- **Older datascan documents are pruned.** Beyond 30 days some fields are dropped
  and the raw response is truncated from 16 KB to 4 KB, so a content comparison
  across the seam can show a difference that is retention, not change.

## Reading a series

ONYPHE rescans on a cadence, not continuously — ctiscan covers the top 100 ports
about twice a week from US and FR vantage points, a wider port range about weekly.

So:

- **A gap of one bucket is usually scan cadence, not an outage.** Widen the
  bucket before calling a service intermittent.
- **First-seen is a lower bound.** The earliest bucket containing the host is the
  earliest ONYPHE *observed* it, not when it appeared.
- **Absence is not down.** A host missing from a bucket may simply not have been
  scanned in that pass.

Changes worth attention, roughly in order:

| Signal | Reading |
|---|---|
| Certificate fingerprint changes | Routine if it tracks a 90-day renewal; significant if the issuer or subject changes with it |
| SSH host key changes | The host was rebuilt or replaced |
| ASN or organisation changes | The address changed hands — treat as an ownership boundary |
| Several independent signals change in the same bucket | The strongest change signal available here. Activity before and after may belong to different operators entirely. |
| A banner version increments | Routine patching |

A cluster of simultaneous changes across independent signals is far stronger
evidence than any single change. Bracket it, and do not carry an attribution
across it without saying you have.

## Common patterns

```bash
# Is this cluster growing, over seven days
for n in 6 5 4 3 2 1 0; do
  printf '%s\t' "$n"
  "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
    "category:ctiscan cert.issuer.cn:\"Major Cobalt Strike\" -dayago:$n"
done

# Find the retention edge before trusting any decline
for n in 0 1 2 3; do
  printf 'monthago:%s\t' "$n"
  "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" "category:ctiscan <query> -monthago:$n"
done

# Which hosts are new this week versus last
comm -13 \
  <(opp 'uniq ip.dest' < data/w1.ndjson | jq -r '.ip.dest' | sort -u) \
  <(opp 'uniq ip.dest' < data/w0.ndjson | jq -r '.ip.dest' | sort -u)

# Oldest first, when the earliest observation is the question
onyphe -size 100 -maxpage 1 -search 'category:ctiscan ip.dest:203.0.113.10 -monthago:1 -sort:0'
```

## Error handling

| Symptom | Cause and fix |
|---|---|
| Series drops to 0 and stays there | Retention edge, not a real decline. Probe the edge as above. |
| Long window refused on Export but fine on Search | The two have separate history depths. Compare `History` and `export` in the preflight. |
| `-monthago` returns 0 on a CTI-only licence | ctiscan retention on those editions is days, not months. Use `-dayago`/`-weekago`. |
| A datascan query returns 0 on a CTI licence | datascan is not on that licence at all. |

## Caveats

- Every bucket is a separate query and a separate credit. A 30-day daily series
  is 30 credits; use weekly buckets when daily resolution is not needed.
- Buckets are calendar-aligned. `-weekago:0` is a partial week until Sunday.
- Comparing counts across the ctiscan/datascan seam compares two different
  scanners. Say so rather than drawing a single line through both.
- `seen_date` and `@timestamp` are per-document; they tell you when this
  observation happened, not how long the thing has existed.

## Cross-references

- **onyphe-search** — the per-bucket count, and the four reasons a 0 is not an absence.
- **onyphe-oql** — time functions, `-sort:0`, and the datascan translation.
- **onyphe-export** — pulling each bucket for content comparison.
- **onyphe-opp** — diffing and deduplicating the buckets.
- **onyphe-alert** — watching forward instead of reconstructing backward.
