# resolver field model (passive DNS)

**`category:resolver` is on Griffin View only.** On a CTI-family edition
(Catfish, Sealion, Shark) every query in this file returns nothing, and nothing
tells you why - an unauthorised category is not an error, it is an empty result.
Check with `onyphe-preflight.sh resolver` before you read a zero as an answer.

Every field in the resolver schema, with its type and **how many documents
carried it in a one-day window, measured 2026-10-29** on a Griffin View licence.
The corpus that day was 268 743 831 documents
(`onyphe -count -search 'category:resolver -dayago:1'`).

The field list is the union of three sources: the published index template
([`resolver-7.json`](https://github.com/onyphe/material/blob/master/datamodels/resolver-7.json),
51 fields), ONYPHE's own Explore projection
(`Explore/Model/Resolver.pm`), and 288 real resolver documents. Two fields
(`@category`, `seen_date`) appear on every real document but in no template -
absence from one source is not absence from the schema.

## Why this table exists

Resolver is the **deepest-reaching category in this package**: 12 months, against
datascan's 7 and ctiscan's ~1. It is the only way to ask what a host was called a
year ago.

But the depth is not uniform. **15 of its 50 queryable fields stop being
searchable at 8 months**, including both `forward` and `reverse`. A query that
filters on one of them returns **0** at depth - which reads exactly like "that
name was never there". The 12 months are real; the 12-month *filter set* is not.

That boundary is measured below. It is **not** the 30 days the published
retention note implies; that figure describes the truncation of the `data` field,
not the removal of searchable ones.

## Fields that exist but carry no data

Do not build a signal on these. All 53 fields were counted over a one-day window;
each of the entries below was re-counted over a whole month (`-monthago:0`) and
returned zero again. This is not a quiet day.

- `geolocus.source` - the only genuinely empty field in the schema. Every other
  `geolocus.*` sub-field is populated on roughly 104-113 million documents a day.

## Fields that exist but cannot be filtered

Separate failure, and a worse one, because the field is plainly visible in your
output. These two are returned on every document and work in `-fields:`
projections, but they are **not searchable**:

- `@category` - `-exists:@category` returns 0. Select the category with the
  `category:` keyword instead, which is a query selector rather than a field.
- `seen_date` - `-exists:seen_date` returns 0, and `seen_date:2026-10-28` is
  rejected outright: `syntax error: validate: invalid word found: seen_date`.
  Project it, sort on it, read it - but do not filter on it. For a time filter
  use `-dayago:`/`-monthago:`/`-since:`.

```bash
# Works: both come back in the projection
onyphe -size 1 -maxpage 1 -search 'category:resolver -dayago:1 -fields:ip,hostname,seen_date,type,source'
```

## Fields stripped beyond 7 months

The part nothing else documents. These 15 fields are populated in recent data and
return **exactly 0** from `-monthago:8` onward. The boundary is sharp: every one
of them is still populated at `-monthago:7`.

| Field | Docs/day | `-monthago:7` | `-monthago:8` |
|---|---:|---:|---:|
| `reverse` | 45 334 674 | 1 586 458 128 | **0** |
| `city` | 92 959 831 | 4 414 617 519 | **0** |
| `company.name` | 2 732 183 | 79 907 649 | **0** |
| `company.fortunerank` | 389 346 | 8 212 832 | **0** |

Full stripped set: `@version`, `city`, `company.country`,
`company.fortunerank`, `company.globalrank`, `company.industry`,
`company.name`, `company.sector`, `forward`, `latitude`, `location`,
`longitude`, `reverse`, `subnet`, `ttl`.

The control that makes those zeros meaningful is `hostname`, measured in the same
buckets: 9 519 355 087 at `-monthago:7` and 8 030 961 463 at `-monthago:8`. The
buckets are full. The fields are gone.

**The operational rule.** Before writing a resolver query with a window longer
than seven months, check every field in it against that list. If one is on it,
substitute:

| Instead of | Beyond 7 months use | Why |
|---|---|---|
| `-exists:reverse` | `type:reverse` | 1 763 518 942 at `-monthago:9` |
| `-exists:forward` / `forward:` | `type:forward` | 4 606 921 339 at `-monthago:9` |
| `subnet:` | `ip:` with CIDR | `ip` is never stripped |

`ip:`, `hostname:`, `domain:` and `type:` all keep working at full depth -
verified at `-monthago:9`: `ip:1.1.1.1` 53 478,
`hostname:one.one.one.one` 946, `domain:cloudflare.com` 936 690.

And the paired-count check, when a long-window query returns 0 and you need to
know which kind of zero it is:

```bash
# record = is anything there at all;  field = is your filter still indexed
onyphe-count.sh 'category:resolver ip:203.0.113.10 -monthago:9'
onyphe-count.sh 'category:resolver ip:203.0.113.10 -exists:reverse -monthago:9'
```

record > 0 with field 0 means the field was stripped, not that the name was
absent. record 0 means absent *in that bucket* - which is still not an absence,
because passive DNS coverage of any domain is partial.

## Populated fields, by layer

### Resolution (`ip`, `hostname`, `domain`, …)

What resolved to what. `hostname` is the field to pivot on - it survives at full
depth where `forward` and `reverse` do not.

| Field | Type | Docs/day |
|---|---|---:|
| `domain` | keyword | 268 740 941 |
| `hostname` | keyword | 268 741 389 |
| `tld` | keyword | 268 741 285 |
| `ip` | ip | 261 351 334 |
| `ipv6` | boolean | 261 351 334 |
| `host` | keyword | 186 109 676 |
| `forward` | keyword | 172 914 486 |
| `subdomains` | keyword | 96 560 092 |
| `reverse` | keyword | 45 334 674 |

`hostname` is **scalar-or-array** - ONYPHE's own Explore model normalises it
both ways. A bare `jq -r '.hostname'` on an array document emits a JSON array as
a string and silently corrupts the name list. Use `opp 'uniq hostname'`, or:

```bash
jq -r '[(.hostname // .reverse // empty) | if type=="array" then .[] else . end] | .[]' \
   resolver.ndjson | sort | uniq -c | sort -rn
```

### Record (`type`, `ttl`, `soa`, …)

| Field | Type | Docs/day |
|---|---|---:|
| `type` | keyword | 268 743 831 |
| `ttl` | integer | 267 434 661 |
| `data` | text | 25 778 039 |
| `datamd5` | keyword | 25 778 039 |
| `soa` | keyword | 16 022 547 |
| `ns` | keyword | 9 580 156 |
| `mx` | keyword | 9 298 588 |
| `txt` | keyword | 8 505 151 |
| `cname` | keyword | 5 835 633 |
| `spf` | keyword | 21 895 |

`datamd5` is an under-used operator pivot. On a `type:soa` document `data` holds
the raw SOA text and `datamd5` its hash, so a shared `datamd5` across two domains
is a shared SOA record - the same DNS operator, not a coincidence.

### Network and geography

| Field | Type | Docs/day |
|---|---|---:|
| `asn` | keyword | 260 127 319 |
| `organization` | keyword | 260 127 317 |
| `subnet` | keyword | 260 154 980 |
| `country` | keyword | 246 291 101 |
| `location` | geo_point | 246 291 243 |
| `latitude` / `longitude` | float | 117 132 932 |
| `city` | keyword | 92 959 831 |
| `geolocus.country` / `.isineu` / `.organization` / `.subnet` | keyword/boolean | 113 259 257 |
| `geolocus.asn` | keyword | 113 242 474 |
| `geolocus.netname` | keyword | 113 204 959 |
| `geolocus.continent` / `.continentname` / `.countryname` / `.latitude` / `.location` / `.longitude` | keyword/float/geo_point | 104 082 892 |
| `geolocus.domain` | keyword | 104 019 230 |
| `company.country` / `.industry` / `.name` / `.sector` | keyword | 2 732 183 |
| `company.globalrank` | integer | 2 342 837 |
| `company.fortunerank` | integer | 389 346 |

`geolocus.*` is a shared enrichment block, not a hunt pivot. The whole
`company.*` block and `city`/`latitude`/`longitude`/`subnet` are stripped past
seven months.

### Provenance and labels

| Field | Type | Docs/day |
|---|---|---:|
| `@timestamp` | date | 268 743 831 |
| `@version` | keyword | 268 743 831 |
| `source` | keyword | 268 743 831 |
| `tag` | keyword | 149 852 691 |

`tag` is array-valued.

## Record types

`type` holds ONYPHE **resolution classes, not DNS record mnemonics.** This is the
single easiest way to write a resolver query that silently matches nothing:
`type:a` returns **0** and `type:ptr` returns **0**.

| `type:` | Docs/day | Meaning |
|---|---:|---|
| `forward` | 172 914 486 | name → address |
| `reverse` | 45 337 109 | address → name |
| `soa` | 16 022 547 | zone authority record |
| `ns` | 9 580 156 | nameserver |
| `mx` | 9 298 588 | mail exchanger |
| `txt` | 8 505 151 | TXT record |
| `cname` | 5 835 635 | alias |
| `spf` | 21 895 | SPF policy |

`type:forward` and `type:reverse` are the depth-safe way to select direction
(see the stripped-field rule above).

## Where the records come from

`source` records how ONYPHE learned the mapping, and it is the most under-used
field in the category. A `ctl` record is a name that appeared on a **certificate**
- not a resolution anyone observed.

| `source:` | Docs/day | What it means |
|---|---:|---|
| `ctiscan` | 100 444 838 | name seen during service scanning |
| `massdns` | 69 583 544 | active bulk resolution |
| `ctl` | 40 652 156 | name taken from certificate transparency |
| `ctiurl` | 36 777 156 | name seen during URL-level (vhost) scanning |
| `massdns::bruteforce` | 13 423 653 | enumerated, not observed |
| `vulnscan` | 6 144 387 | name seen during vulnerability scanning |
| `datascan` | 418 795 | name seen during datascan |

Two consequences for a hunt. First, `ctl` and `ctiurl` together are ~29% of a
day's records, so a large slice of passive DNS is **certificate- and
vhost-derived rather than resolution-derived** - report `source` rather than
filtering it away, because certificate-derived names are often the most
attributable ones. Second, `massdns::bruteforce` names were guessed by
enumeration; a hit there is weaker evidence of operator intent than a `ctl` or
`ctiscan` name.

## Retention

Twelve months, Griffin View only.

| Window | Documents |
|---|---:|
| `-dayago:1` | 268 743 831 |
| `-monthago:0` | 7 016 166 345 |
| `-monthago:7` | 9 908 209 257 |
| `-monthago:8` | 8 065 188 088 |
| `-monthago:12` | 883 099 652 |
| `-monthago:13` | **0** |

`-since:12M` is accepted and returned 95 972 087 957; `-since:7M` returned
58 641 829 207. The edge is between month 12 and month 13, and `-monthago:12` is
already partial.

## Field type semantics

The type system is shared with ctiscan - see
[ctiscan-fields.md](ctiscan-fields.md) for what each type supports
(`keyword` exact/wildcard/regexp, `text` full-text phrase only, `ip` CIDR,
`float` not searchable).

Two resolver-specific notes: `hostname` and `tag` are array-capable, and
resolver uses the **datascan** field model - `ip:`, not `ip.dest:`. A ctiscan
field name here returns 0 with no error.

## Regenerating this table

The counts date from 2026-10-29 and will drift. The authoritative field list is
the index template at
<https://github.com/onyphe/material/blob/master/datamodels/resolver-7.json>.

```bash
while read -r f; do
  printf '%s\t' "$f"
  onyphe-count.sh "category:resolver -exists:$f -dayago:1"
done < resolver-fields.txt
```

One credit per field, 53 fields. Re-deriving the stripped set costs another 50
(the same loop at `-monthago:8`), and the boundary bisection 45 more. The full
re-measure behind this file, including the type and source censuses and the
retention ladder, was about 230 counts.

To re-verify a single row without spending any of that:

```bash
onyphe-count.sh 'category:resolver -exists:reverse -dayago:1'
onyphe-count.sh 'category:resolver -exists:reverse -monthago:8'   # expect 0
```

For the live field list rather than the template:

```bash
onyphe -search 'category:resolver -dayago:1' -size 1 | jq -r 'paths(scalars) | join(".")'
```

That yields the fields populated on *that* document, so it under-reports - which
is the right direction to err in. It is also how the `company.*` block was
briefly mistaken for stripped: it sits on only ~1% of documents, so a 100-document
sample missed it entirely while a count found it alive at every depth to seven
months. Sample to find candidates; always confirm with a count.
