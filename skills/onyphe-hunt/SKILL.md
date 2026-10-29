---
name: onyphe-hunt
description: >-
  Use when the user explicitly asks for a multi-step ONYPHE investigation —
  e.g. "onyphe hunt," "onyphe investigate," "hunt for related infrastructure,"
  "deep dive into this cluster with onyphe," "full onyphe investigation," or
  "/onyphe-hunt." This is a heavyweight methodology skill: a typical hunt
  spends 60-200 credits and takes several minutes at ONYPHE's ~1 request per
  second. Do NOT fire on a single lookup like "what does onyphe know about this
  IP" (use onyphe-summary) or a single query (use onyphe-search). Runs a fixed
  baseline, then branches on what the baseline shows, with a mandatory
  deception gate before anything is called a finding. Always confirms scope and
  estimated cost with the user before starting.
version: 1.1.0
---

# onyphe-hunt

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

Fires on explicit multi-step investigation requests — work that needs a
methodology across several ONYPHE calls, not one query. Typical triggers:

- "hunt for infrastructure related to 203.0.113.10"
- "onyphe investigate this certificate"
- "find the rest of this cluster"
- "full onyphe investigation on this ASN"

**Not** for "what's on this IP" (`onyphe-summary`), a single query
(`onyphe-search`), or "is this a honeypot" (`onyphe-honeypot`).

**Before starting:** confirm the target, the estimated credit cost, and whether
the user wants the full methodology or a lighter pass. A baseline alone is
roughly 15–30 credits; a hunt with two or three pivot branches is 40–150.
Griffin View licences have unlimited credits, so there the figures only
translate into request volume and wall-clock time.

**Precedence:** where this skill disagrees with a command skill
(`onyphe-search`, `onyphe-export`, `onyphe-oql`…), the command skill wins. They
own the facts about their own behaviour; this skill owns the method.

## Phase 0 — Preflight

```bash
# Fatal. ctiscan and ctiurl ship together on every licence that has either.
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-preflight.sh" ctiscan ctiurl

# Advisory, and asked separately: resolver is Griffin View only, and
# preflight exits 3 on the first unauthorised category in a list.
if "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-preflight.sh" resolver >/dev/null 2>&1; then
   RESOLVER=yes
else
   RESOLVER=no    # CTI-only licence: Catfish, Sealion, Shark
fi
```

Read four things off it and carry them through the whole hunt:

- **Categories.** If ctiscan is absent, this methodology does not apply.
  If datascan is absent, the hunt cannot go back further than ctiscan retention.
- **History depth.** Sets the widest defensible window.
- **Functions.** `?` OR, condition groups and regexp are licence-gated, and the
  list is necessary but not sufficient — a listed function can still be refused
  at query time. Verify the ones this hunt depends on with a 1-credit count.
- **Passive DNS.** `category:resolver` is **Griffin View only**. Phases 2b and 5b
  work on every licence; phase 2c and the depth track of phase 6 need Griffin
  View. On a CTI-only licence say so in `findings.md` *before* you start: the
  ceiling on this hunt is ctiscan's ~1 month, and no query will tell you that —
  an unauthorised category returns nothing rather than an error.

## Phase 1 — Scaffold

```
YYYY-MM-DD_description/
├── data/            raw NDJSON, nothing deleted
├── analysis/
│   └── findings.md  initialised from references/findings-template.md
└── src/             any throwaway scripts
```

Three layers, deliberately: `findings.md` holds conclusions, `data/` holds
observations, and the commands in this skill are what connects them. Someone
should be able to re-derive the conclusion from the directory alone.

## Phase 2 — Baseline

```bash
# What ONYPHE holds across every category (datascan-model, NOT ctiscan)
onyphe -summary ip <TARGET> > data/summary_<TARGET>.ndjson

# The CTI view, which the summary does not include. Both corpora at once:
# the comma list returns the union, and both use the ctiscan field model.
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:ctiscan,ctiurl ip.dest:<TARGET> -weekago:1'
onyphe -size 100 -maxpage 1 -search \
  'category:ctiscan,ctiurl ip.dest:<TARGET> -weekago:1
   -fields:category,ip.dest,ip.asn,ip.organization,ip.country,tcp.dest,services.count,services.port,
app.protocol,app.device,app.tls,component.product,component.cpe,cert.subject.cn,cert.issuer.cn,
cert.fingerprint.md5,ja3s.fingerprint.md5,tcp.fingerprint.md5,http.header.data.md5,
favicon.data.md5,hhhash.fingerprint.md5,dns.reverse.hostname,http.hostname,http.url,http.code,
html.title.raw,tag,seen_date' \
  > data/cti_<TARGET>.ndjson
```

The summary and the CTI search are **both** required. Summary never returns
ctiscan or ctiurl documents — reporting only the summary understates the host by
an entire data model.

`category` comes back as `@category` and is what separates the two document kinds
in the saved file. Split the counts before reading anything into them:

```bash
jq -r '."@category"' data/cti_<TARGET>.ndjson | sort | uniq -c
```

Populate *Host profile* and *Services* in `findings.md`.

## Phase 2b — The vhost view

A ctiscan document is an **IP:port service**, reached by scanning an IP. A ctiurl
document is a **URL on a virtual host**, reached by name — and ONYPHE builds that
name list from certificate transparency, live TLS and hostnames extracted from
response bodies, not from the IP. So an IP-keyed hunt structurally misses
name-only infrastructure: shared hosting where your actor is one tenant among
hundreds, and CDN fronting where `ip.dest` belongs to the CDN.

`http.hostname` is the field that carries the vhost, and it is the discriminator
between the two corpora — 25 287 226 of 25 287 230 ctiurl documents carry it
against 1 455 ctiscan documents a day (measured 2026-10-29). Pull the name-keyed
view on its own, because the union would bury ~25M ctiurl documents under ~215M
ctiscan ones:

```bash
onyphe -size 100 -maxpage 1 -search \
  'category:ctiurl ip.dest:<TARGET> -weekago:1
   -fields:ip.dest,tcp.dest,app.tls,http.hostname,http.url,http.code,html.title.raw,
cert.subject.cn,extract.hostname,extract.domain,tag,seen_date' \
  > data/ctiurl_<TARGET>.ndjson

opp 'uniq http.hostname | addcount' < data/ctiurl_<TARGET>.ndjson | tail -1
```

A zero here is a statement about ONYPHE's vhost target list, **not** about the
host: it means no name ONYPHE knows points at this IP. Record it as that.

Populate *Vhost profile* in `findings.md`.

## Phase 2c — Passive DNS (Griffin View only)

Skip if `RESOLVER=no` from phase 0, and write the skip into `findings.md` as
*"category:resolver not authorised on this licence"* — never as a zero.

Passive DNS is the join between the IP-keyed and name-keyed views: reverse gives
you candidate vhosts for an IP, forward gives you other IPs for a name. It is
also the only category here that reaches **12 months**.

**Dialect changes.** Resolver uses the *datascan* model: `ip:`, not `ip.dest:`.
A ctiscan field name returns 0 with no error.

```bash
# Count first. The 1M/12M pair is the host's naming depth for one extra credit.
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:resolver ip:<TARGET> -since:1M'
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:resolver ip:<TARGET> -since:12M'

"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-export.sh" \
  'category:resolver ip:<TARGET> -since:12M' \
  ip,hostname,reverse,forward,domain,tld,type,ttl,source,tag,asn,organization,country,seen_date \
  data/resolver_<TARGET>.ndjson

# hostname is scalar-or-array: a bare jq -r '.hostname' corrupts the name list.
jq -r '[(.hostname // .reverse // empty) | if type=="array" then .[] else . end] | .[]' \
   data/resolver_<TARGET>.ndjson | sort | uniq -c | sort -rn
```

Then forward, and the infrastructure pivots:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:resolver hostname:<NAME> -since:12M'
onyphe -search 'category:resolver domain:<DOMAIN> -since:7M | uniq hostname'
onyphe -search 'category:resolver type:ns ( ?hostname:ns1.<DOMAIN> ?hostname:ns2.<DOMAIN> ) -since:7M | dedup ns | fields @timestamp,ns | addcount'
```

**Report `source`, do not filter it.** It records how ONYPHE learned the mapping
— `ctl` 40 652 156/day and `ctiurl` 36 777 156/day against `massdns` 69 583 544
and `ctiscan` 100 444 838 (2026-10-29). A `ctl` record is a name that appeared on
a *certificate*, not a resolution anyone observed, and
`massdns::bruteforce` names were guessed by enumeration. Certificate-derived
names are often the most attributable ones, so filtering them away is the wrong
instinct — but a hunt that treats a bruteforced name as operator intent is
overreading.

### The passive-DNS gate

Resolver's failure mode is not deception, so `onyphe-hpcheck.sh` does not apply —
resolver documents have no `services.*` at all. The failure here is
**non-attributable naming**: the name is real, it just was not the operator's
choice. For each candidate name `H` on target IP `T`:

| | Test | Cost |
|---|---|---|
| G0 | Does `H` embed `T`'s octets (dotted, dashed or reversed)? | 0, offline |
| G1 | `category:resolver hostname:H -since:1M` — does it exist at all? | 1 |
| G2 | `category:resolver hostname:H !ip:T -since:1M` — does it point anywhere else? | 1 |
| G3 | Names per IP, from the phase-2c export | 0 |
| G4 | `-wildcard:hostname,host-*.provider.example !ip:T` — is it a provider template? | 1 |

- **G0 matches, or G4 is large** → placeholder PTR. The provider applied it
  across its whole allocation; the operator never chose it. Provider context
  only, never a pivot seed. One real hunt recorded 75 695 such documents on a
  single domain.
- **G3 high** → shared hosting, parking or CDN. The name does not attribute the
  IP and the IP does not attribute the name.
- **G2 = 0, G3 low, no G0** → pinned, operator-chosen. Promote to a pivot seed —
  still subject to the two-independent-indicators rule in phase 5.
- **G1 = 0** → inconclusive, with the usual four exclusions plus a fifth that is
  resolver-specific: *was the window longer than seven months with a stripped
  field in the filter?* (see phase 6).

Gate the top five names by document count and record the cap.

Also remember resolver coverage is **partial** — one hunt found ONYPHE held only
`dev.` and the apex for a domain that plainly had more. A name absent from
resolver may resolve perfectly well.

## Phase 3 — Indicator extraction and rarity

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-rarity.sh" <TARGET> --window -weekago:1 \
  > data/rarity_<TARGET>.tsv

# Only if phase 2b found vhosts. Run it as a SECOND pass, never pooled.
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-rarity.sh" <TARGET> --window -weekago:1 \
  --category ctiurl > data/rarity_<TARGET>_ctiurl.tsv
```

Classify every value by population (see `onyphe-pivot` for the bands): unique at
1, useful at 2–25, shared tooling at 25–1000, library-or-provider above that.

**Rarity is the one place not to merge the two corpora.** A band is a claim about
a denominator, and the denominators differ by an order of magnitude —
214 531 635 ctiscan documents a day against 25 287 230 ctiurl ones (2026-10-29).
Pooling rescales every band by a different factor per field, and the seed pull is
only `-size 10`, so a union seed is filled by whichever corpus sorts first. Run
the two passes separately and label which produced each value. Rarity scoring is
ctiscan-dialect only, so it cannot be pointed at `category:resolver` at all.

Two things that look like tradecraft and are not:

- **A stack fingerprint.** JA3S and the TCP fingerprint routinely sit in the tens
  of millions. They identify a TLS library or an OS, never an operator.
- **A provider fleet artefact.** A hosting provider running its own service on
  every VPS it rents gives every host in your cluster a shared attribute. Test it:
  ```bash
  "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
    'category:ctiscan <attribute> !ip.asn:<the host ASN> -weekago:1'
  ```
  Use the same category as the rarity pass that produced the attribute — a count
  and its own control must share a denominator. If that returns 0, the attribute
  is locked to one provider. Drop it — it
  carries no attribution weight and the query dies the moment the operator moves.

Populate *Indicator triage*.

## Phase 4 — Deception gate (mandatory)

Run **every** surviving indicator through the four-count check before it goes
into a pivot:

```bash
# ctiscan gate
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-hpcheck.sh" '<indicator fragment>' --window -weekago:1

# ctiurl gate — a separate run, because the base rates are not comparable
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-hpcheck.sh" '<indicator fragment>' --window -weekago:1 \
  --base 'category:ctiurl'
```

About one ctiscan document in nine is already tagged as deception, and
`!tag:honeypot` alone is not a control — see `onyphe-honeypot` for why, and for
what to do with a low-`hpish` candidate that still needs its residual profiled.

**Do not carry the ctiscan base rate into ctiurl.** Measured 2026-10-29 on a
one-day window: `tag:honeypot` is 24 321 936 of 214 531 635 ctiscan documents
(**11.3%**) but 3 894 of 25 287 230 ctiurl documents (**0.015%**) — a factor of
about 740. An `hpish%` that looks alarming against ctiscan expectations may be
unremarkable for ctiurl, and vice versa. Quote each gate against its own corpus.

The `mp199` column does carry over, but thinly: `services.count:199` is 4 094
ctiurl documents a day, none of them tagged. It is a host-level ctiscan fleet
heuristic inherited by the URL documents of those hosts, so treat a 0 there as
the control not transferring — **not** as a clean result.

A ctiurl total of 0 makes `onyphe-hpcheck.sh` exit 2, which it documents as
*inconclusive, not clean*. That will be common, because most indicators are
host-level. It licenses nothing about safety and does not block the ctiscan
pivot.

The ctiurl-native control worth running per candidate is vhost fan-out: compare
`uniq ip.dest,http.hostname` against `uniq ip.dest` on the pivot pull. Hundreds
of unrelated names on one IP is shared hosting — the ctiurl analogue of a
provider fleet artefact.

This phase is not optional and not reorderable. Pivoting on an unvalidated
indicator produces a large, confident, wrong cluster.

## Phase 5 — Pivot

For each indicator that survived phase 4, in rarity order:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:ctiscan,ctiurl <indicator> -weekago:1'
# one extra credit, so the split is reportable: ctiscan hits = union - ctiurl
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:ctiurl <indicator> -weekago:1'

"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-export.sh" \
  'category:ctiscan,ctiurl <indicator> -weekago:1' \
  category,ip.dest,ip.asn,ip.organization,ip.country,tcp.dest,services.count,app.device,http.hostname,cert.fingerprint.md5,tag \
  data/pivot_<name>.ndjson

opp 'uniq ip.dest | addcount'                        < data/pivot_<name>.ndjson | tail -1
opp 'uniq ip.dest,tcp.dest,http.hostname | addcount' < data/pivot_<name>.ndjson | tail -1
jq -r '.ip.asn // empty' data/pivot_<name>.ndjson | sort -u
```

**Both dedupe lines, and report both numbers.** `uniq ip.dest` alone assumed one
document per host, which the union breaks on two axes at once — many ports and
many vhosts per IP. 40 vhosts on 3 IPs is shared hosting; 3 vhosts on 40 IPs is
an operator; collapsed to `uniq ip.dest` those are the same number. Note that
`uniq` discards every other field, so run it on a copy or re-read the file.

Decision trees for what to do with each shape of result are in
[references/decision-trees.md](references/decision-trees.md), and the per-field
pivot patterns — including which ones are worth running against ctiurl — are in
[references/pivot-patterns.md](references/pivot-patterns.md).

**Two independent indicators before a host joins the cluster.** Independent
means not derived from each other — a certificate fingerprint and a body hash
qualify; the MD5 and SHA-256 of the same bytes are one indicator counted twice.

## Phase 5b — Name-keyed pivot

Only when phase 2b or 2c produced names. The IP pivot asks *who else runs this
service*; this asks *where else does this name live*.

```bash
# every IP that answered for this name
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:ctiscan,ctiurl http.hostname:"<NAME>" -weekago:1'

# the whole domain, licence permitting
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:ctiscan,ctiurl -wildcard:http.hostname,*.<DOMAIN> -weekago:1'

# names the actor's own pages referenced — candidate vhosts on other IPs
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:ctiscan,ctiurl extract.domain:"<DOMAIN>" -weekago:1'
```

Carrying a name across the seam: resolver `hostname`/`reverse` → ctiurl
`http.hostname:`, or ctiscan `dns.reverse.hostname:` (89 616 623 docs/day).
Prefer `dns.reverse.hostname` over `dns.forward.hostname` — the forward twin
carries only 812 documents a day, so a zero there means *not populated*, not
*not resolving*.

## Phase 6 — Time

Once the cluster is defined, establish whether it is growing, and how far back
the evidence actually goes:

### Track A — resolution (every licence)

```bash
for n in 6 5 4 3 2 1 0; do
  printf '%s\t' "$n"
  "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
    "category:ctiscan,ctiurl <indicator> -dayago:$n"
done
```

Probe the retention edge before reading any decline as real — ctiscan returns 0
from about two months back regardless of what was there. See `onyphe-timeline`.

The two corpora are grouped at the same ~1 month retention, but that is an
assumption until you check it. **If the union series steps by more than about a
third in a single bucket, re-run it once per category before believing it** — a
ctiurl collapse is invisible inside a series dominated by ctiscan volume.

### Track B — depth (Griffin View only)

```bash
for n in 0 1 2 3 4 5 6 7 8 9 10 11 12; do
  printf 'monthago:%s\t' "$n"
  "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
    "category:resolver ip:<TARGET> -monthago:$n"
done
```

| Preflight | Depth | What it gets you |
|---|---|---|
| `resolver` present | **12 months**, naming only | The deepest reach available. No service content. |
| `datascan` present | 7 months, service content | Use when the question is what was *listening*, not what it was *called*. |
| Both absent (CTI-only) | ctiscan's ~1 month is a **hard floor** | Stop at the edge and report the window you could cover. Do not present an empty long-window result as an answer. |

### The seven-month fidelity cliff

Resolver keeps 12 months of *records* but only about 7 months of *searchable
fields*. **15 of its 50 queryable fields return 0 from `-monthago:8`**, including
both `forward` and `reverse` (measured 2026-10-29; full list in
`onyphe-oql/references/resolver-fields.md`). A query filtering on one of them
returns 0 at depth, which reads exactly like "that name was never there".

Before writing any resolver query with a window longer than seven months, check
every field in it against that list. `ip:`, `hostname:`, `domain:` and `type:`
all survive — so select direction with `type:reverse` rather than
`-exists:reverse`.

When a long-window query does return 0, the paired count tells you which kind of
zero it is:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:resolver ip:<TARGET> -monthago:9'
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:resolver ip:<TARGET> -exists:reverse -monthago:9'
```

Record > 0 with field 0 means the **field** was stripped. Both 0 means absent in
that bucket — still not an absence, because passive DNS coverage is partial.

## Phase 7 — Persist

If the cluster is worth watching, propose an alert — and confirm the query,
recipient and threshold with the user before creating it. See `onyphe-alert`.

## Data preservation

Everything goes in `data/`, nothing is deleted.

```
data/summary_<ip>.ndjson
data/cti_<ip>.ndjson              # ctiscan + ctiurl union, phase 2
data/ctiurl_<ip>.ndjson           # name-keyed view, phase 2b
data/resolver_<ip>.ndjson         # passive DNS, phase 2c (Griffin View)
data/rarity_<ip>.tsv
data/rarity_<ip>_ctiurl.tsv
data/pivot_<name>.ndjson
data/hpcheck_<name>.tsv
data/hpcheck_<name>_ctiurl.tsv
```

**A zero-result query is a finding and is kept.** Record the query and the four
exclusions that make the zero meaningful — dialect, `-exists:`, window, licence.
An unrecorded zero gets re-run by the next person at the same cost.

## Findings template

Initialise `analysis/findings.md` from
[references/findings-template.md](references/findings-template.md) at the start,
not the end. Every section is populated or explicitly marked N/A before the hunt
is called complete.

## Reporting

Three rules, all of which exist because the opposite has produced wrong answers:

1. **Distinct hosts, not documents.** One IP contributes many documents. Quote
   `uniq ip.dest` counts, and say which you are quoting. When the pull was a
   union, quote **hosts and host:port:vhost** — the ratio between them is what
   separates shared hosting from an operator estate, and one number alone cannot.
2. **State the window with every number.** "6 hosts" is meaningless; "6 documents
   in a one-day window on 2026-09-25" can be checked.
3. **Say what you did not exclude.** If the residual was not profiled, if only
   one indicator was confirmed, if the window was shorter than asked for —
   say so in the findings, not in a footnote.

## Cost

Arithmetic over the commands each phase runs, not a measurement.

| Phase | Credits |
|---|---|
| 0 Preflight | 2 (second call probes resolver) |
| 2 Baseline | 3–5 |
| 2b Vhost view | 1–2 |
| 2c Passive DNS | 6–14, Griffin View only (incl. 2–3 per gated name) |
| 3 Rarity | 15–30 ctiscan, plus 5–15 if a ctiurl pass runs |
| 4 Deception gate | 4 per indicator, 8 when it has a ctiurl population |
| 5 Pivot | 3–11 per branch |
| 5b Name-keyed pivot | 1–3 per name |
| 6 Time | 7 (track A) + 13 (track B) + 2 per paired control |

A focused hunt is 60–90 credits. A broad one with several branches and both
corpora exceeds 200. At roughly one request per second, that is minutes of wall
clock, not seconds. On an unlimited Griffin View licence the figures translate
into request volume and wall clock rather than cost.

## Cross-references

- **onyphe-search** — counting, sampling, and the four reasons a zero is not an absence.
- **onyphe-export** — pulling a cluster past the 10 000-result ceiling.
- **onyphe-summary** — phase 2, and what it does not cover.
- **onyphe-pivot** — phases 3 and 5 in detail.
- **onyphe-honeypot** — phase 4 in full.
- **onyphe-timeline** — phase 6, and the retention cliff.
- **onyphe-alert** — phase 7.
- **onyphe-oql** — field names and the dialect trap, consulted throughout; the
  resolver field model and its seven-month stripped-field list.
- **onyphe-opp** — deduplicating and analysing everything in `data/`.
- **onyphe-asd-discover** / **onyphe-asm-assess** — when the target is the user's own asset inventory rather than an unknown actor.
