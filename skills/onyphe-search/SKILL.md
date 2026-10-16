---
name: onyphe-search
description: Use when the user wants to run an ONYPHE search, query ONYPHE for hosts or services, find ONYPHE ctiscan/ctiurl documents matching a condition, count how many hosts match an OQL query, or search ONYPHE for a certificate/banner/hash. Wraps the `onyphe -search` and `onyphe -count -search` CLI modes. Trigger phrases include "onyphe search," "search onyphe for," "how many hosts on onyphe," "onyphe query for," "find on onyphe," and "count onyphe results." Not for pulling a full population without a result ceiling (see onyphe-export), single-asset lookup by IP/domain/hostname (see onyphe-summary), or help writing the query string itself (see onyphe-oql).
version: 1.0.0
---

# onyphe-search

> **Field names follow the category.** `ctiscan` and `ctiurl` use the ctiscan
> data model; every other category uses the datascan one. A field from the wrong
> model returns 0 with no error. When you carry a value from a summary or datascan
> result into a ctiscan query, translate the field name first
> ([map](../onyphe-oql/references/datascan-ctiscan-map.md)).

## When to use

Use this skill to run an OQL query against ONYPHE and get matching documents
back, or to get the exact number of documents that match. Covers requests like:

- "search onyphe for Cobalt Strike C2s"
- "how many ctiscan hosts run this favicon hash"
- "onyphe query for expired certs on port 8443"
- "find hosts sharing this HTTP header hash"

If the user needs the whole population rather than a sample, and it is larger
than the Search API's 10 000-result ceiling, that is `onyphe-export`. If they
have one IP, domain or hostname and want everything ONYPHE holds about it, that
is `onyphe-summary`. If they need help constructing the OQL itself, defer to
`onyphe-oql`.

## Count before you pull

`-count` asks the server for the total and returns a single `{"total":N}`
document. It costs one credit, makes one round trip, and the number is exact:
it is not a page count, not capped, and not a floor.

```bash
onyphe -count -search 'category:ctiscan app.device:c2 -dayago:1'
# {"total":3411,...}

"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:ctiscan app.device:c2 -dayago:1'
# 3411
```

Run this first, every time, before deciding how to retrieve anything. It is the
cheapest question you can ask and it determines which of the next three
paragraphs applies:

| Total | What to do |
|---|---|
| 0 | Do **not** report "nothing found" yet. See *Zero is not an answer* below. |
| up to ~10 000 | `onyphe -search` with an explicit `-size`/`-maxpage`. |
| more than 10 000 | `onyphe-export` — Search cannot reach past the ceiling. |

## Invocation

```bash
onyphe [-size N] [-maxpage N] -search '<OQL> [| <OPP pipeline>]'
```

| Flag | Meaning |
|---|---|
| `-count` | Return only the total. Forces `size=1`, `maxpage=1`. One credit. |
| `-size <0..10000>` | Results per page. CLI default 10; 100 is the practical page size. |
| `-maxpage <N>` | Pages to fetch. **Set this explicitly, always** — see below. |
| `-fields:` (in the OQL) | Server-side field projection. Cuts credits-per-volume and output size. |
| `-postsearch` | Same query over POST. Use when the OQL is long or quote-heavy enough to be awkward in a URL. |

### Always set `-maxpage` explicitly

The page limit comes from `~/.onyphe.ini`, and the CLI's own `install.sh` writes
`api_maxpage = 1000`. A command that looks like a single query can therefore page
a thousand times. Never rely on the inherited default:

```bash
# One page of 100. Bounded and predictable.
onyphe -size 100 -maxpage 1 -search 'category:ctiscan app.device:c2 -dayago:1'
```

### Search API ceiling

Search returns at most **10 000 results** — 100 pages of 100. Past that, results
are unreachable through this endpoint regardless of `-maxpage`. The count tells
you in advance whether you are about to hit it; when you are, switch to
`onyphe-export`.

## Common patterns

```bash
# Scope, then retrieve, with a projection
onyphe -count -search 'category:ctiscan cert.issuer.cn:"Major Cobalt Strike" -dayago:1'
onyphe -size 100 -maxpage 1 -search \
  'category:ctiscan cert.issuer.cn:"Major Cobalt Strike" -dayago:1
   -fields:ip.dest,tcp.dest,cert.fingerprint.md5,tag'

# Count a set of candidate values in one loop
for h in 15af977ce25de452b96affa2addb1036 f4febc55ea12b31ae17cfb7e614afda8; do
  printf '%s\t' "$h"
  "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
    "category:ctiscan ja3s.fingerprint.md5:\"$h\" -dayago:1"
done

# Post-process in the same call with an OPP pipeline
onyphe -size 100 -maxpage 1 -search \
  'category:ctiscan app.device:c2 -dayago:1 | uniq ip.dest | addcount'

# Long or quote-heavy query over POST
onyphe -maxpage 1 -postsearch 'category:ctiscan -regexp:html.title.raw,".*honeypot.*"'
```

## Interpreting results

Output is **NDJSON on stdout**, one document per line. There is no JSON-array,
CSV or table mode. Errors and warnings go to stderr, so a pipe into `opp` or
`jq` stays clean without redirection.

Two fields come back whether or not you asked for them: `@category` and
`seen_date`. A `-fields:` projection trims everything else.

### Zero is not an answer

A count of 0 has at least four causes, and only one of them is "this does not
exist":

1. **Wrong field dialect.** A datascan field name under `category:ctiscan`
   returns exactly 0 with no error. Measured on a one-day window: `data:"Apache"`
   returns 0 where `app.data.text:"Apache"` returns 7 663 474; `port:443` returns
   0 where `tcp.dest:443` returns 23 194 680. See `onyphe-oql` for the full
   translation table.
2. **Field not populated at all.** Confirm with `-exists:` before concluding the
   value is rare:
   ```bash
   onyphe -count -search 'category:ctiscan -exists:<field> -dayago:1'
   ```
   If that is 0, the field carries no data on this licence and your query was
   never going to match.
3. **Window too narrow.** ctiscan rescans on a cadence, not continuously. Widen
   `-dayago:1` to `-weekago:1` before deciding a host is gone.
4. **Category not on the licence.** Run
   `"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-preflight.sh" ctiscan ctiurl` — an
   unauthorised category returns nothing rather than an error.

Only after all four are excluded is 0 a finding. Record it as one; a zero-hit
result is evidence and is worth keeping.

## Error handling

| Symptom | Cause and fix |
|---|---|
| `access denied: filter not allowed: <name>` (error 12) | The field does not exist, or is not on this licence. Check `onyphe-preflight.sh` and `onyphe-oql`. |
| `syntax error: validate: missing closing group after` | An OQLv2 condition group is unbalanced. Groups need a space inside the parentheses: `( ?a:1 ?b:2 )`. |
| `WARNING: Too fast, sleeping before retry...` | HTTP 429. The CLI sleeps 1 s and retries **indefinitely** on its own — it will not give up, so a command that looks hung may just be rate-limited. The API runs at roughly 1 request/second. |
| Empty output, no error | Very often the dialect trap above. Re-read the field names before believing it. |
| `no more credits` (error 1005) | Licence exhausted. `onyphe-preflight.sh` shows the balance. |

## Caveats

- **`-verbose` does nothing.** The flag is parsed but the verbosity is reset
  unconditionally during client init, so the debug path is unreachable from the
  CLI. Diagnose from stderr instead.
- Exactly **one API mode per invocation**. `-search` and `-export` in the same
  command is not two queries; the dispatch chain picks one.
- The CLI splits the argument at the **first unquoted `|`**: everything left is
  OQL, everything right is an OPP pipeline. A `|` inside a double-quoted OQL
  value is safe. `-fields:` must sit on the OQL side — after the pipe it reads as
  an argument to a proc.
- `-fields:` (OQL, server-side) and `| fields` (OPP, client-side) are different
  things with nearly the same name. See `onyphe-opp`.
- Without a time function the query defaults to roughly the **last 30 days**. Be
  explicit when the window matters.
- **Run one `onyphe` command at a time** when the results matter. The API is
  rate-limited to about 1 request/second and the client's own answer to a 429 is
  an unbounded retry loop, so parallel invocations mostly serialise anyway —
  slower, with less visibility into which call is waiting.

## Cross-references

- **onyphe-oql** — query syntax, ctiscan field model, and the datascan translation table. Go here to build or debug the query string.
- **onyphe-export** — populations past the 10 000-result ceiling.
- **onyphe-summary** — everything ONYPHE holds on one IP, domain or hostname.
- **onyphe-opp** — the `| ...` pipeline and post-retrieval analysis.
- **onyphe-pivot** — turning one result into a rarity-scored set of next queries.
- **onyphe-honeypot** — before treating any population statistic as real.
