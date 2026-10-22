---
name: onyphe-export
description: Use when the user wants to pull a complete ONYPHE population rather than a sample — e.g. "onyphe export," "export all onyphe results for," "dump every host matching," "pull the full ctiscan population," "onyphe bulk pull," or "get more than 10000 results from onyphe." Wraps `onyphe -export` and `-postexport`, which stream NDJSON with no page limit and no result ceiling. Always requires a `-fields:` projection. Not for sampling or counting (see onyphe-search), and not available on every licence — check with onyphe-preflight first.
version: 1.0.1
---

# onyphe-export

> **Field names follow the category.** `ctiscan` and `ctiurl` use the ctiscan
> data model; every other category uses the datascan one. A field from the wrong
> model returns 0 with no error. When you carry a value from a summary or datascan
> result into a ctiscan query, translate the field name first
> ([map](../onyphe-oql/references/datascan-ctiscan-map.md)).
>
> **OR is `?`, NOT is `!` — there is no `OR`/`NOT` keyword.**
> `( ?domain:a.com ?domain:b.com )`; a literal `OR` fails with
> `filter not allowed: ORdomain` ([syntax](../onyphe-oql/SKILL.md)).

## When to use

Use this skill when the answer needs the whole matching population, not a page
of it — typically because `onyphe-search`'s count came back above the Search
API's 10 000-result ceiling. Typical asks:

- "export every host with this certificate fingerprint"
- "pull the full population for this CPE over the last week"
- "dump all ctiurl documents with this title so I can analyse the markup"

For a sample, a count, or anything under the ceiling, use `onyphe-search`. It is
cheaper to reason about and easier to bound.

## Prerequisites

Export is licence-gated and its history depth differs from Search's. Confirm
before building the command:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-preflight.sh"
```

The output's `History` and `export` figures are the two numbers that matter — a
licence can allow a longer window on Search than on Export, so a time function
that works on one may be refused on the other.

## Invocation

```bash
onyphe -export '<OQL> -fields:<field,field,...> [| <OPP pipeline>]'
```

Or, with the projection enforced:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-export.sh" '<OQL>' '<field,field,...>' [outfile]
```

The script refuses to run without a field list, places `-fields:` on the OQL
side of any `|`, streams NDJSON to stdout (or a file), and reports the document
count on stderr so the stdout stream stays pipeable.

### `-fields:` is not optional

Export has **no page limit and no result ceiling**. Whatever matches, streams.
`-fields:` is the only lever that bounds how much comes back per document, and
it is a triple win: fewer credits per unit of data, a smaller file, and far less
of the agent's context spent on fields nobody asked for.

Pick the projection from the question. A useful ctiscan default for
infrastructure work:

```
ip.dest,ip.asn,ip.organization,ip.country,tcp.dest,app.protocol,app.device,
component.product,cert.subject.cn,cert.issuer.cn,dns.reverse.hostname,tag,seen_date
```

## Common patterns

```bash
# Always scope first. Export has nothing to stop a query broader than intended.
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
  'category:ctiscan component.cpe:"cpe:/a:apache:http_server:-" -dayago:1'

# Then pull, projected, to a file
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-export.sh" \
  'category:ctiscan component.cpe:"cpe:/a:apache:http_server:-" -dayago:1' \
  ip.dest,tcp.dest,component.version,tag \
  data/apache.ndjson

# Straight into the pipeline, no intermediate file
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-export.sh" \
  'category:ctiscan app.device:c2 -dayago:1' ip.dest,cert.issuer.cn,tag \
  | opp 'uniq cert.issuer.cn | addcount'

# ctiurl, when the analysis needs whole response bodies
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-export.sh" \
  'category:ctiurl html.title.text:"index of" -weekago:1' \
  ip.dest,http.url,html.title.raw,app.data.length \
  data/opendir.ndjson
```

## Interpreting results

Streaming NDJSON, one document per line, in whatever order the server produces.
There is no total in the stream — you already have it from the count.

**A truncated file looks exactly like a complete one.** The stream can end early
on a network fault without a non-zero exit. Before analysing, compare what you
received against what you were promised:

```bash
wc -l < data/apache.ndjson      # against the count you ran first
```

A shortfall means re-run, not "the population shrank".

### Deduplicate before quoting any population statistic

Export returns documents, not hosts. One IP can contribute many documents —
several services, several URLs, several scan passes in the window. A raw line
count is an upper bound on hosts, often a wild one.

```bash
opp 'uniq ip.dest | addcount' < data/apache.ndjson | tail -1
```

The same applies to any shared fingerprint: a single cloned template can account
for most of a corpus. Count distinct hosts per fingerprint value before treating
a number as a measure of deployment.

## Error handling

| Symptom | Cause and fix |
|---|---|
| Export mode rejected or unauthorised | Not on this licence. `onyphe-preflight.sh` shows which APIs are included. |
| Time function refused on Export but fine on Search | The two have separate history depths. Compare `History` and `export` in the preflight output and shorten the window. |
| Stream ends early, file short of the count | Transport failure. Re-run; do not analyse the partial file. |
| `WARNING: Too fast, sleeping before retry...` | HTTP 429. The client sleeps and retries indefinitely on its own. A long-running export that has gone quiet is usually waiting, not dead. |

## Caveats

- **There is no ceiling to save you.** Search stops at 10 000; Export does not
  stop. A query one field short of what you meant will stream until it finishes.
  Count first, without exception.
- Export streams and does not page, so `-maxpage` and `-size` are irrelevant here.
- `-fields:` must sit on the OQL side of the first `|`. After the pipe the CLI
  reads it as an argument to an OPP proc.
- `@category` and `seen_date` come back regardless of the projection.
- Output is NDJSON only. For a text layout, add `| output` to the pipeline; for
  anything else, post-process with `onyphe-opp`.
- `-postexport` is the POST form, for queries too long or quote-heavy for a URL.
  It has the same semantics otherwise.

## Cross-references

- **onyphe-search** — count first, and sample anything under the ceiling.
- **onyphe-oql** — field names, the `-fields:` function, and time functions.
- **onyphe-opp** — analysing the NDJSON once it has landed.
- **onyphe-honeypot** — before any exported population becomes a statistic.
