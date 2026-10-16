---
name: onyphe-opp
description: Use when the user wants to filter, project, deduplicate, count or correlate ONYPHE results — e.g. "onyphe pipeline," "OPP," "onyphe post-processing," "dedupe these onyphe results," "count unique values in onyphe output," "analyse the saved ndjson," or "correlate these onyphe results against another category." Covers the OPP pipeline both inline after `|` in an OQL argument and standalone via the `opp` binary over saved NDJSON. Not for producing the data in the first place (see onyphe-search or onyphe-export) or for query syntax (see onyphe-oql).
version: 1.0.0
---

# onyphe-opp

## When to use

Use this skill once ONYPHE documents exist — or are about to — and the question
is what to do with them: trim fields, drop duplicates, count distinct values,
keep only documents matching a local condition, or join against another ONYPHE
category.

OPP runs in two places:

```bash
# Inline: everything after the first unquoted | is a pipeline
onyphe -size 100 -maxpage 1 -search 'category:ctiscan app.device:c2 -dayago:1 | uniq ip.dest'

# Standalone: same procs, over NDJSON already on disk
opp 'uniq ip.dest | addcount' < data/c2.ndjson
```

## Core principle

**Save once, analyse many times.** Every ONYPHE call costs credits and runs
against a ~1 request/second limit. When a second question arrives about the same
data — "now only the German ones", "now by ASN" — answer it with `opp` against
the saved file, not with another query.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-export.sh" 'category:ctiscan app.device:c2 -weekago:1' \
  ip.dest,ip.asn,ip.country,ip.organization,tcp.dest,cert.issuer.cn,tag \
  data/c2.ndjson

opp 'uniq cert.issuer.cn' < data/c2.ndjson
opp 'filter services.count:>=150' < data/c2.ndjson
```

## Procs

| Proc | Does |
|---|---|
| `fields a,b,c` | Keep only these fields |
| `uniq a,b` | Deduplicate on these fields, **discarding every other field** |
| `dedup a,b` | Deduplicate on these fields, **keeping the whole document** |
| `expand a` | One document per array value of `a` |
| `exists a` | Keep documents where `a` is populated |
| `filter a:>=N` | Numeric compare — `>`, `>=`, `<`, `<=`, `=` |
| `regex a="re" outputfield=x` | Capture `$1` into `x`; drops non-matching documents |
| `rename src=dst` | Rename a field |
| `addfield k=v` | Add a constant field |
| `fieldcount a` | Add `acount` — how many values `a` has |
| `addcount` | Add a **running index**, not a frequency (see below) |
| `count` | Replace the stream with `{count:N}` |
| `top a` | Value → frequency histogram (see the dot caveat below) |
| `flatten` | Emit dotted keys instead of nested objects |
| `splitsubnet` | Split a CIDR wider than /16 into /16 chunks |
| `output` | Print `field:"value"` text; emits nothing downstream |
| `exec cmd` | Pipe each document through a shell command |
| `whois ip\|domain` | Shell out to `whois`, result in `data` |
| `lookup / orlookup / andlookup f.csv` | Tag documents from a CSV |
| `allowlist / blocklist f.csv` | Keep or drop by CSV match |
| `search / where / merge` | Correlate against another ONYPHE query |
| `discovery` | Re-query the Bulk Discovery API per field value |
| `pivots` | Emit one document per pivotable value |
| `noop` | Pass through |

Proc names are case-insensitive. The same proc may appear twice in one pipeline.

## Two traps worth knowing before you use them

### `addcount` is a running index, not a frequency

```bash
onyphe ... '... | uniq cert.issuer.cn | addcount'
# {"cert":{"issuer":{"cn":"WR1"}},"count":16}
# {"cert":{"issuer":{"cn":"GlobalSign RSA OV SSL CA 2018"}},"count":17}
```

`count: 17` means "this is the 17th document out of the pipeline", not "this
value occurred 17 times". After `uniq` the final `count` is the number of
distinct values — useful — but per-document it is a sequence number. Reading it
as a frequency silently invents data.

### `top` corrupts any value containing a dot

The pipeline unflattens dotted keys on output, and `top` puts the *value* in the
key position. So a value with a dot in it becomes nested structure:

```bash
onyphe ... '... -fields:ip.dest | top ip.dest'
# {"103":{"119":{"14":{"83":1}}}, "106":{"15":{"106":{"108":1}}}, ...}
```

`103.119.14.83` became four levels of nesting. Adding `| flatten` afterwards does
not fix it. This affects IPs, domains, hostnames, versions, CPEs, and
organisation names like `Alibaba (US) Technology Co., Ltd.`

`top` is safe on **dot-free** values — country codes, ports, tags:

```bash
onyphe ... '... -fields:ip.country | top ip.country'
# {"AE":1,"AU":1,"BR":1,"CA":2,"CH":1,"CN":142,"DE":9,...}
```

For anything dotted, count outside the pipeline:

```bash
onyphe ... '... -fields:ip.organization' | jq -r '.ip.organization // empty' \
  | sort | uniq -c | sort -rn | head
# 69 Hangzhou Alibaba Advertising Co.,Ltd.
# 61 Alibaba (US) Technology Co., Ltd.
```

## `-fields:` versus `| fields`

Nearly the same name, entirely different economics:

| | Where | When |
|---|---|---|
| `-fields:a,b` | OQL function, server-side | Before transfer. Reduces credits, bytes and context. |
| `\| fields a,b` | OPP proc, client-side | After transfer. The full document was already fetched and paid for. |

Use `-fields:` to bound what comes back, and `| fields` only to trim further
inside a pipeline, or when working from a file where the cost is already sunk.

## Correlation procs

`search`, `where` and `merge` run a second ONYPHE query per document, with
`$field` substituted from the current one. They differ only in what survives:

| Proc | Result |
|---|---|
| `search` | The remote document **replaces** the local one |
| `where` | The **local** document is kept, if the remote query matched |
| `merge` | Remote fields are merged into the local document, remote wins |

```bash
# Keep only C2 hosts that also appear in riskscan
onyphe -size 100 -maxpage 1 -search \
  'category:ctiscan app.device:c2 -dayago:1 | where category:riskscan ip:$ip.dest'
```

These are **one API call per document**. On a 500-document stream that is 500
calls at ~1/second. Bound the input first — `uniq` before correlating, not after.

## Common patterns

```bash
# Distinct hosts, not documents - the number most population claims need
opp 'uniq ip.dest | addcount' < data/c2.ndjson | tail -1

# Which certificate issuers appear, and how many distinct ones
opp 'uniq cert.issuer.cn | addcount' < data/c2.ndjson | tail -1

# Sprawling service footprints - the honeypot shape
opp 'filter services.count:>=150 | fields ip.dest,services.count,tag' < data/c2.ndjson

# One document per open port
opp 'expand services.port | fields ip.dest,services.port' < data/c2.ndjson

# Extract a token from the response body into its own field
onyphe -export 'category:ctiscan app.protocol:http -dayago:1 -fields:ip.dest,app.data.text
  | regex app.data.text="x-powered-by: ([a-z0-9/.]+)" outputfield=powered
  | uniq powered'

# Human-readable text instead of NDJSON
opp 'fields ip.dest,tcp.dest,tag | output' < data/c2.ndjson
```

## Error handling

| Symptom | Cause and fix |
|---|---|
| Pipeline appears to do nothing | The `|` was inside quotes the CLI treats as OQL, or the proc name is misspelled. Proc names are single words, case-insensitive. |
| `| rdap` dies on load | The proc is unshipped — its dependency is not declared and it is absent from the distribution manifest. Use `| whois` instead. |
| An OQL function after the `|` is ignored | `-fields:`, `-dayago:` and friends are OQL and must sit left of the first unquoted `|`. |
| Correlation pipeline crawls | One API call per document at ~1/second. Reduce the stream first. |
| Nested output where flat was expected | The unflatten step. Add `| flatten`, except after `top`, where it does not help. |

## Caveats

- Output is NDJSON. `| output` gives text; there is no CSV or table mode. CSV is
  an *input* format only, for the lookup and list procs.
- `uniq` discards every field except the ones it deduplicates on. Use `dedup`
  to keep the whole document.
- In `andlookup` CSVs, a **blank cell means the field must be absent** and `*`
  means "do not check". A blank where `*` was meant inverts the rule.
- `| exec` runs a shell command per document. Treat it as the escape hatch, not
  a default.

## Cross-references

- **onyphe-search** — producing the documents, and counting before pulling.
- **onyphe-export** — full populations, streamed, with a projection.
- **onyphe-oql** — `-fields:` and the server-side functions.
- **onyphe-pivot** — `pivots`, `search`/`where`/`merge` used as hunting moves.
