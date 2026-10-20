---
name: onyphe-oql
description: Use when the user needs help with OQL, ONYPHE Query Language syntax, how to write an ONYPHE query, which ONYPHE fields exist, or why an ONYPHE query returned nothing — field names, operators, condition groups, time functions, wildcards and regexp, and the ctiscan/ctiurl versus datascan field translation. Trigger phrases include "OQL syntax," "onyphe query syntax," "how do I write an onyphe query," "what onyphe fields are available," "onyphe query help," and "why does my onyphe query return 0." This is a reference skill, not a CLI wrapper — defer to onyphe-search or onyphe-export to actually run the query once it is built.
version: 1.1.0
---

# onyphe-oql

> **Field names follow the category.** `ctiscan` and `ctiurl` use the ctiscan
> data model; every other category uses the datascan one. A field from the wrong
> model returns 0 with no error. When you carry a value from a summary or datascan
> result into a ctiscan query, translate the field name first
> ([map](references/datascan-ctiscan-map.md)).

## When to use

Use this skill to construct, debug or explain an OQL query — field paths,
operators, grouping, quoting, time windows — and above all when a query returned
0 and the reason is not obvious.

This skill does not run anything. Once the query is right, hand it to
`onyphe-search` (sampling and counting) or `onyphe-export` (full populations).

## Query shape

```
category:<CATEGORY> field:<value> field:<value> -<function>:<value>
```

- **There is no `OR`, `AND` or `NOT` keyword.** Writing one is not a licence
  problem and not "OR unsupported": the parser glues it to the next token as a
  field name and fails with `filter not allowed: ORdomain`. Use the prefixes below.
- **AND is implicit.** Adjacent terms all have to match.
- `!field:value` — NOT.
- `?field:value` — OR. Requires a Lion View licence or above.
- `-function:value` — a server-side function, always prefixed with `-`.
- Values are **not** case-sensitive. Field names **are**, and are always lowercase.
- Quote any value containing a space: `cert.subject.cn:"Major Cobalt Strike"`.

### Condition groups

OQLv2 supports parentheses, **and needs a space inside them**:

```
category:ctiscan ( ?services.port:8080 ?services.port:1723 ) ( !services.port:80 !services.port:443 )
```

Writing `(?a:1 ?b:2)` without the inner spaces produces
`syntax error: validate: missing closing group after`. Check your licence's
`OQL version` with `onyphe-preflight.sh`; groups need version 2.

### Several values of one field (OR)

Put `?` on **every** term and wrap them in a spaced group so the OR does not
bleed into the rest of the query:

```
# WRONG - OR is not a keyword: error 12, "filter not allowed: ORdomain"
category:datascan (domain:revolut.com OR domain:revolut.codes OR domain:revolutlabs.com)

# RIGHT
category:datascan ( ?domain:revolut.com ?domain:revolut.codes ?domain:revolutlabs.com )

# Different fields are fine too: either condition, then AND a third
category:ctiscan ( ?tcp.dest:8080 ?app.protocol:socks ) -dayago:1
```

Quote a value that contains a space, colon, parenthesis or bracket:
`?cert.subject.cn:"Major Cobalt Strike"`.

### Several patterns of one field (OR / NOT with wildcard functions)

For `keyword` fields, the pattern functions have OR and NOT forms of their own.
Repeat the function; each repeat is OR-combined:

```
# Any of these patterns (alias -owd:)
category:datascan -orwildcard:domain,revolut.* -orwildcard:domain,revolut*.com

# Match one pattern, exclude another (alias -nwd:), and an exact exclusion with !
category:datascan -wildcard:domain,revolut.* -notwildcard:domain,revolut.fake.* !domain:revolut.example

# Regexp equivalents (anchored, case-insensitive): -orregexp: / -notregexp:
category:datascan -orregexp:domain,"revolut[a-z0-9-]*\\.com" -notregexp:domain,".*\\.fake\\.com"
```

`?` is one character and `*` zero or more in a wildcard pattern. Both families
match `keyword` fields only; on a `text` field they never match, with no error.

## The single most common cause of a 0 result

**ctiscan/ctiurl and datascan are different data models.** A datascan field name
under `category:ctiscan` does not error. It returns exactly 0.

Measured 2026-09-25 over one day, same intent, both forms:

| datascan name under ctiscan | ctiscan native | |
|---|---|---|
| `data:"Apache"` → **0** | `app.data.text:"Apache"` → 7 663 474 | |
| `cpe:"cpe:/a:apache:http_server:-"` → **0** | `component.cpe:"..."` → 3 063 115 | |
| `port:443` → **0** | `tcp.dest:443` → 23 194 680 | |
| `status:200` → **0** | `http.code:200` → 33 224 626 | |
| `protocol:http` → **0** | `app.protocol:http` → 176 146 431 | |
| `device.class:c2` → **0** | `app.device:c2` → 3 411 | |
| `app.http.title:"index of"` → **0** | `html.title.text:"index of"` → 91 744 | |

The full translation table, both directions, is in
[references/datascan-ctiscan-map.md](references/datascan-ctiscan-map.md).

## Fields

Every ctiscan/ctiurl field, its type, and **how many documents actually carry
it**, is in [references/ctiscan-fields.md](references/ctiscan-fields.md).

Read that file before building a signal on an unfamiliar field. 47 of the 216
fields in the published schema carry no data at all — including JARM, JA4S,
JA4T, domhash and ssdeep. A query against one of them returns 0 forever, and
nothing warns you.

The short version of the field types:

| Type | Matching |
|---|---|
| `keyword` | exact, `-wildcard:`, `-regexp:` |
| `text` | full-text phrase only — **no** wildcard, **no** regexp |
| `ip` | CIDR, but nothing broader than /16 |
| numeric | exact |
| `float` | not searchable |

Many ctiscan fields come as a `.raw` / `.text` pair: `html.title.raw` is exact
and regexp-able, `html.title.text` is full-text. Pointing `-regexp:` at a `.text`
field is not an error — it simply never matches, which is the worst kind of
failure.

## Functions

Full table with licence gates in
[references/oql-functions.md](references/oql-functions.md). The ones used
constantly:

```
-dayago:1        -weekago:1      -monthago:3      -hourago:0
-since:7d        -since:1M
-exists:<field>  -notexists:<field>   -orexists:<field>
-fields:<f1,f2>  -sort:0
-wildcard:<field>,<pattern>      -regexp:<field>,"<re>"
```

Every function also has a short alias — `-da:`, `-wa:`, `-ma:`, `-ha:`, `-si:`,
`-ex:`, `-nex:`, `-oex:`, `-fi:`, `-so:`, `-wd:`, `-re:`, `-nre:`, `-nwd:`,
`-ore:`, `-owd:`. The long forms are clearer; the short ones matter when a URL
length limit bites, at which point `-postsearch` is usually the better answer.

**Functions are licence-gated** — `onyphe-preflight.sh` lists which ones the key
is granted. Treat that list as necessary but not sufficient: a function can be
listed and still be refused at query time. Verify any function you intend to
build on with a single 1-credit count before relying on it, and read a refusal
as "use another route", not as "the data is not there". For expired
certificates, for instance, `cert.validity.expired:true` is a plain filter and
needs no function at all.

## Building a query that works

1. **Name the category explicitly**, and use that category's field names. Without
   one the server assumes `datascan` (and its model), which is rarely what a
   hunt wants.
2. **Bound the window.** No time function means roughly the last 30 days.
3. **Check the field is populated** before treating a narrow result as rare:
   ```bash
   onyphe -count -search 'category:ctiscan -exists:<field> -dayago:1'
   ```
4. **Project.** `-fields:` cuts volume, credits and context.
5. **Count before you pull.** See `onyphe-search`.

### Scoping a service condition

`services.port` lists every open port on the host; `tcp.dest` is the port this
document is about. They answer different questions:

```
# hosts that have 3389 open somewhere
category:ctiscan services.port:3389

# documents that ARE the service on 3389
category:ctiscan tcp.dest:3389

# hosts with 8080 open but neither 80 nor 443 - a shape, not a product
category:ctiscan ( ?services.port:8080 ) ( !services.port:80 !services.port:443 )
```

### Regexp

`-regexp:` is **anchored and case-insensitive**, so patterns are written
lowercase and wrapped in `.*` when a substring is meant:

```
-regexp:http.header.data.raw,".*server: 360 web server, .*"
-regexp:cert.subject.dn,"cn=[a-z0-9]{15}"
```

Escaped metacharacters need **doubled** backslashes: `\\.` for a literal dot.
Regexp works only on `keyword` fields — never on a `.text` field. It is
I/O-intensive and can time out; retry rather than assuming zero.

## Worked examples

More in [references/cookbook.md](references/cookbook.md), every one of them
count-verified against live data. The tag vocabulary — `risk::*`, device
classes, vulnerability verdicts — is in
[references/tag-vocabulary.md](references/tag-vocabulary.md).

```bash
# Cobalt Strike team servers by certificate
category:ctiscan cert.issuer.cn:"Major Cobalt Strike" -dayago:1

# Everything ONYPHE classes as C2
category:ctiscan app.device:c2 -dayago:1

# Open directories, URL level
category:ctiurl html.title.text:"index of" -weekago:1

# One host, full ctiscan view
category:ctiscan ip.dest:203.0.113.10 -weekago:1

# Hosts sharing a response-header hash across the week
category:ctiscan http.header.data.md5:"f7430cdb1622717dcc6c0bf53b71e7b3" -weekago:1
```

## Error handling

| Message | Meaning |
|---|---|
| `access denied: filter not allowed: <name>` (error 12) | The field does not exist or is not on this licence. |
| `syntax error: validate: missing closing group after` | Unbalanced group, or missing the space inside the parentheses. |
| `syntax error: validate: closing group never opened after` | A `)` with no matching `(`. |
| `syntax error: validate: invalid word found:` | A stray token — often an unquoted value containing a space. |
| No error, 0 results | Almost always the dialect trap, an unpopulated field, or too narrow a window. |

## Caveats

- `-fields:` (OQL, server-side) and `| fields` (OPP, client-side) are different
  mechanisms with nearly the same name. See `onyphe-opp`.
- The CLI splits its argument at the first **unquoted** `|`. OQL functions must
  sit to the left of it.
- CIDR works only on `ip`, `alternativeip` and `app.extract.ip`, and only down
  to /16. For anything broader, split the range — OPP's `| splitsubnet` does it.
- `?` OR, condition groups and regexp each need a sufficient licence. A query
  that works for one analyst can be refused for another.
- Values containing a double quote cannot be quoted safely; match a distinctive
  substring instead.

## Cross-references

- **onyphe-search** — run the query, and count it first.
- **onyphe-export** — populations past the 10 000-result ceiling.
- **onyphe-opp** — the `| ...` half of the argument.
- **onyphe-pivot** — which fields are worth pivoting on, and how rare each value is.
- **onyphe-honeypot** — why a population count is not yet a finding.
