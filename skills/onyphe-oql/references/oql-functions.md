# OQL functions

Functions are server-side, always prefixed with `-`, and always sit on the OQL
side of any `|`. They are **licence-gated**: run
`onyphe-preflight.sh` and read the `OQL functions` line to see which ones a key
can actually use. A function the licence does not grant is refused, not ignored.

Every function has a short alias. The long form is clearer and should be the
default; the short form exists for when a GET URL is running out of room, at
which point `-postsearch` / `-postexport` is usually the better fix.

## Time

| Function | Alias | Meaning |
|---|---|---|
| `-hourago:N` | `-ha:` | Whole hour, N hours back. `0` = current hour. |
| `-dayago:N` | `-da:` | Whole day, N days back. `0` = today, 00:00–23:59. |
| `-weekago:N` | `-wa:` | Whole week, Monday 00:00 – Sunday 23:59. |
| `-monthago:N` | `-ma:` | Whole calendar month. |
| `-since:PERIOD` | `-si:` | Rolling window: `7d`, `1w`, `1M`, `7M`, `48M`. |

These select a **bucket**, not a rolling window — `-dayago:1` is all of
yesterday, not the last 24 hours. For a time series, iterate the bucket:

```bash
for n in 0 1 2 3 4 5 6; do
  printf '%s\t' "$n"
  onyphe-count.sh "category:ctiscan app.device:c2 -dayago:$n"
done
```

With no time function at all, the query covers roughly the last 30 days.

## Existence

| Function | Alias | Meaning |
|---|---|---|
| `-exists:FIELD` | `-ex:` | Field is populated |
| `-notexists:FIELD` | `-nex:` | Field is absent |
| `-orexists:FIELD` | `-oex:` | Repeatable, OR-combined |

`-exists:` is the control probe for any rarity claim. Before calling a value
rare, confirm the field carries data at all:

```bash
onyphe -count -search 'category:ctiscan -exists:jarm.fingerprint.md5 -monthago:1'
# 0 - JARM is in the schema but unpopulated, so every JARM query returns 0
```

## Pattern matching

| Function | Alias | Meaning |
|---|---|---|
| `-wildcard:FIELD,PATTERN` | `-wd:` | `?` = one char, `*` = zero or more |
| `-orwildcard:FIELD,PATTERN` | `-owd:` | Repeatable, OR-combined |
| `-notwildcard:FIELD,PATTERN` | `-nwd:` | Exclusion |
| `-regexp:FIELD,"RE"` | `-re:` | Regular expression |
| `-orregexp:FIELD,"RE"` | `-ore:` | Repeatable, OR-combined |
| `-notregexp:FIELD,"RE"` | `-nre:` | Exclusion |

Combining them (`-owd:`/`-nwd:` are the aliases of the OR and NOT forms):

```
# OR: repeat the function
category:datascan -orwildcard:domain,example.* -orwildcard:domain,example*.com
# NOT: keep one pattern, drop another
category:datascan -wildcard:domain,example.* -notwildcard:domain,example.fake.*
```

For plain values use `?field:v` (OR) and `!field:v` (NOT), grouped as
`( ?domain:a.com ?domain:b.com )`. There is no `OR`/`NOT` keyword; see the
[syntax section](../SKILL.md).

Both families work on **`keyword` fields only**. Against a `text` field they do
not error — they simply never match. Check the type in
[ctiscan-fields.md](ctiscan-fields.md) first. This is why honeypot candidates
that key on response bodies are validated with a phrase match or `app.data.md5`
rather than `-regexp:app.data.text,...`.

`-regexp:` is **anchored and case-insensitive**. Write the pattern lowercase and
wrap it in `.*` for a substring:

```
-regexp:http.header.data.raw,".*x-powered-by: thinkphp.*"
-regexp:html.title.raw,".*honeypot.*"
```

Escaped metacharacters need doubled backslashes: `g[^\.o]ogle[a-z0-9-]*\\.[a-z\.]{1,}`.

Both are I/O-intensive and may return a request timeout. Retry; a timeout is not
a zero.

## Output control

| Function | Alias | Meaning |
|---|---|---|
| `-fields:f1,f2,...` | `-fi:` | Server-side projection |
| `-sort:0` | `-so:` | Oldest first (default is newest first) |

`-fields:` is the main cost and context lever: fewer bytes per document, less
volume billed, less of the agent's window spent on fields nobody asked for. Use
it on every retrieval. `@category` and `seen_date` come back regardless.

Do not confuse it with OPP's `| fields`, which filters client-side after the
documents have already been transferred and paid for.

## Advertised is not the same as accepted

The function list from `onyphe -user` is a **necessary condition, not a
sufficient one**. A function can appear on the licence and still be refused at
query time, returning `400 unknown function: <name>` (error 12).

Read that error as "this route is unavailable, find another", not as a
permission problem — re-checking the licence will not change it. Verify any
function a hunt depends on with one 1-credit count before building on it:

```
onyphe -count -search 'category:ctiscan <your function here> -dayago:1'
```

Where a plain filter exists, prefer it: `cert.validity.expired:true` needs no
function at all.

For expired certificates, use the field instead - it is populated and works:

```
category:ctiscan cert.validity.expired:true -dayago:1
```

## Typosquat and lookalike patterns

The pattern functions are what make lookalike hunting possible:

```
category:resolver -wildcard:domain,g??gle.com !domain:google.com
category:datascan -wildcard:hostname,*.google.com.* -notwildcard:domain,google.*
category:ctl -regexp:domain,"g[^\.o]ogle[a-z0-9-]*\\.[a-z\.]{1,}" -since:1w
```

Note these are written against `resolver`, `datascan` and `ctl`, whose field
names differ from ctiscan's. See [datascan-ctiscan-map.md](datascan-ctiscan-map.md).
