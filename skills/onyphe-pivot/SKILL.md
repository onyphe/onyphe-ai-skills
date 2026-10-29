---
name: onyphe-pivot
description: Use when the user wants to find infrastructure related to something they already have — e.g. "onyphe pivot," "find related infrastructure," "what else shares this certificate/hash/fingerprint," "onyphe rarity analysis," "which of this host's attributes are distinctive," "expand from this IP," or "unique values for this field." Covers the ctiscan and ctiurl pivot-field sets, passive-DNS pivots, rarity scoring with onyphe-rarity.sh, the OPP correlation procs, and the ASD pivot-query API for server-side unique values. Not for a plain criteria search (see onyphe-search) or a single-asset lookup (see onyphe-summary).
version: 1.1.0
---

# onyphe-pivot

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

Use this skill when you have one thing — a host, a certificate, a hash — and
want the others that belong with it. Typical asks:

- "what else uses this certificate"
- "which of this host's attributes are worth pivoting on"
- "find the rest of this cluster"
- "list every distinct issuer among these C2s"

## Rarity comes before pivoting

An attribute is only a pivot if it is *rare*. Most of a host's attributes are
shared with millions of unrelated hosts, and pivoting on one of those produces a
large, confident, meaningless result set.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-rarity.sh" 203.0.113.10
```

This pulls the host's ctiscan document, extracts every value of the curated
pivot set, counts the population sharing each, and prints them rarest first.
One credit per attribute value; `--dry-run` shows the plan and spends nothing.

A real table, from one Cobalt Strike team server on 2026-09-25, one-day window:

```
1         cert.fingerprint.md5     562664f622db669088fdf3c299d910ed
1         cert.issuer.cn           vm-0-12-ubuntu-ca@1781535044
1         cert.serial.hex          7b:93:20:39
6         cert.issuer.cn           Major Cobalt Strike
6         cert.subject.cn          Major Cobalt Strike
100780    cert.serial.hex          2
1312931   app.data.md5             83d07b842b1ed2327b161b1279847633
1381944   ip.asn                   AS45090
1431503   hhhash.fingerprint.md5   d48c64decf66ecf4a84314da49343f84
16398668  app.data.md5             3c768c4828bc7cf16f444a4228eaa0b3
26812618  ja3s.fingerprint.md5     15af977ce25de452b96affa2addb1036
41074061  tcp.fingerprint.md5      a3b90b3a3a1182e974c9b5d678f07c35
```

Everything in this table is an attribute of the same host. The JA3S fingerprint
is shared with 26.8 million documents — it identifies a TLS library, not an
operator. `cert.serial.hex:2` is a default. The two usable pivots are the
certificate fingerprint (1) and the Cobalt Strike issuer CN (6).

Read the table as:

| Population | Meaning |
|---|---|
| 1 | Unique — nothing to pivot *to*, but a strong identifier for tracking |
| 2–25 | The useful band. Pivot here. |
| 25–1000 | Shared tooling, a hosting template, or a product default |
| Over ~1000 | A library, a stack, or a provider. Not attribution. |
| 0 | The field is unpopulated. Check before concluding anything. |

**A band is a claim about a denominator, so score each corpus separately.**
ctiscan carried 214 531 635 documents on 2026-10-29 against ctiurl's
25 287 230 — roughly an order of magnitude apart, and the gap is not uniform
across fields. Pooling the two rescales every band by a different factor and the
table stops meaning what it says. `onyphe-rarity.sh` takes `--category` for this;
run it twice and label which pass produced each value:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-rarity.sh" 203.0.113.10 --window -weekago:1
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-rarity.sh" 203.0.113.10 --window -weekago:1 --category ctiurl
```

The flag accepts `ctiscan`, `ctiurl` and the comma list, and rejects anything
else — the seed pull keys on `ip.dest` and every default field is a
ctiscan-model name, so a datascan-model category would return 0 with no error.
That means **rarity scoring cannot be pointed at `category:resolver`**; count
passive-DNS candidates directly with `onyphe-count.sh` instead.

## The pivot fields that work

Verified populated on 2026-09-25; see `onyphe-oql`'s field reference for counts.

| Class | Fields |
|---|---|
| Certificate | `cert.fingerprint.md5` / `.sha256`, `cert.serial.hex`, `cert.subject.cn`, `cert.issuer.cn`, `cert.subject.o` |
| TLS stack | `ja3s.fingerprint.md5` |
| TCP stack | `tcp.fingerprint.md5` |
| Response | `app.data.md5` / `.sha256` |
| HTTP header set | `http.header.data.md5` / `.sha256`, `hhhash.fingerprint.md5` |
| HTTP body | `http.body.data.md5` / `.sha256` |
| Favicon | `favicon.data.md5` / `.mmh3` |
| SSH | `ssh.fingerprint.md5` / `.sha256`, `hassh.fingerprint.md5` |
| Headers | `http.header.etag`, `http.header.server` |
| Trackers | `tracker.ga`, `tracker.gtm`, `tracker.fbq`, and the rest of `tracker.*` |
| Context | `component.text`, `entity.text`, `ip.asn`, `ip.organization` |
| Vhost / URL | `http.hostname`, `http.url`, `extract.hostname`, `extract.domain` |

### Which corpus to pivot in

`category:ctiscan,ctiurl` queries both at once and both use the same field
model, so most pivots above should be run against the union — the question "who
else shows this artefact" has no reason to stop at the IP-keyed corpus.

Three exceptions, and one rule:

- **`ssh.*` and `hassh.*`: ctiscan only.** A ctiurl document is an HTTP fetch,
  so those fields are definitionally empty there.
- **`services.*` shapes: ctiscan only.** They describe the host; the URL
  documents of that host inherit the field without adding to the question.
- **`http.hostname` and the vhost row: ctiurl in practice.** It carries
  25 287 226 of 25 287 230 ctiurl documents against 1 455 ctiscan documents a
  day (2026-10-29) — the field is the discriminator between the two corpora.
- **The rule: rarity is measured per corpus, never pooled.** See below.

### Passive DNS pivots (Griffin View only)

`category:resolver` uses the **datascan** model — `ip:`, not `ip.dest:` — and is
not available on CTI-family licences. It answers a different question from every
field above: not *who else runs this software*, but *what else was this called,
and where else did the name live*.

| Class | Fields |
|---|---|
| Name | `hostname`, `domain`, `tld`, `host`, `subdomains` |
| Address | `ip`, `asn`, `organization` |
| Record | `type`, `soa`, `ns`, `mx`, `cname`, `datamd5` |
| Provenance | `source` |

The strongest of these is not a name at all: on `type:soa` documents `datamd5`
hashes the raw SOA record, so two domains sharing a `datamd5` share a DNS
operator. `type:` takes ONYPHE resolution classes (`forward`, `reverse`, `soa`,
`ns`, `mx`, `txt`, `cname`, `spf`) — `type:a` and `type:ptr` match nothing.

Beyond seven months `forward` and `reverse` stop being searchable; use
`type:forward` / `type:reverse`. Full field model and the stripped list:
[`onyphe-oql/references/resolver-fields.md`](../onyphe-oql/references/resolver-fields.md).

### Fields that look like pivots and are not

**JARM, JA4S, JA4T, domhash and ssdeep carry no data.** They are in the schema
and in the query builder, and `-exists:` returns 0 for every one of them over a
one-month window. A JARM pivot will return nothing, forever, without an error.

Use JA3S, the TCP fingerprint, HHHash and the response hashes instead.

## Pivoting moves

```bash
# 1. Count the candidate before pulling anything
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
  'category:ctiscan,ctiurl cert.fingerprint.md5:"562664f622db669088fdf3c299d910ed" -weekago:1'

# 1b. One more credit splits the result, so you can say where the hits landed
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
  'category:ctiurl cert.fingerprint.md5:"562664f622db669088fdf3c299d910ed" -weekago:1'

# 2. Pull the cluster, projected. Keep `category` so the two kinds stay separable.
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-export.sh" \
  'category:ctiscan,ctiurl cert.issuer.cn:"Major Cobalt Strike" -weekago:1' \
  category,ip.dest,ip.asn,ip.organization,ip.country,tcp.dest,http.hostname,cert.fingerprint.md5,tag \
  data/cluster.ndjson

# 3. Distinct hosts AND distinct host:port:vhost — quote both
opp 'uniq ip.dest | addcount'                        < data/cluster.ndjson | tail -1
opp 'uniq ip.dest,tcp.dest,http.hostname | addcount' < data/cluster.ndjson | tail -1

# 4. How many ASNs does it span? A cluster across several unrelated providers
#    is a stronger signal than one confined to a single hosting fleet.
jq -r '.ip.asn // empty' data/cluster.ndjson | sort -u
```

Step 3 is two lines because `uniq ip.dest` assumes one document per host, and
the union breaks that on two axes at once — many ports and many vhosts per IP.
40 vhosts on 3 IPs is shared hosting; 3 vhosts on 40 IPs is an operator estate;
collapsed to distinct hosts they are the same number. `uniq` discards every
other field, so run it on a copy or re-read the file.

### Server-side unique values

`-asd-pivot-query` returns the distinct values of a field for a query, computed
server-side, with no paging:

```bash
onyphe -asd-pivot-query 'category:ctiscan app.device:c2 -dayago:1' -field cert.issuer.cn
# {"cert":{"issuer":{"cn":"adaptix-local"}}}
# {"cert":{"issuer":{"cn":"vigor router"}}}
# ...107 distinct values
```

It is not ctiscan-only. `category:ctiurl` with `-field http.hostname` enumerates
every virtual host ONYPHE has seen on an address, server-side and without
paging — the cheapest way to tell a single-tenant box from shared hosting:

```bash
onyphe -asd-pivot-query 'category:ctiurl ip.dest:203.0.113.10 -dayago:1' -field http.hostname
# {"http":{"hostname":"example.com"}}
# {"http":{"hostname":"www.example.net"}}      <- unrelated second-level domain
# ...
```

Several unrelated second-level domains in that output means the address is
shared, and `ip.dest` attributes the host to the hoster rather than to your
operator. `category:resolver` is accepted too (verified 2026-10-29), with the
datascan field names.

Three things to know:

- **Scope it before you run it.** A broad ctiurl or resolver pivot streams a very
  large value set: `category:resolver domain:cloudflare.com -dayago:1` was
  refused outright with `error 1011` on 1 044 939 results, and an unscoped
  `category:ctiurl tag:opendir` pivot had not returned after 90 seconds. Pin it
  to one address or one domain first.
- **Values come back lowercased.** Feeding one straight back into an OQL query
  is fine — values are matched case-insensitively — but do not present it as the
  literal string observed on the host.
- **It returns no counts.** It answers "which values exist", not "how many of
  each". Pair it with `onyphe-count.sh` per value when the distribution matters.

It is licence-gated. On `error 1011, too many results, you should create a task`,
re-run with `-astask 1` and poll with `-asd-task-poll <id>`. Pass exactly one
`-asd-*` flag per invocation — the CLI selects the mode by iterating a hash, so
two flags produce a non-deterministic choice.

### Correlating in the pipeline

```bash
# Keep only cluster members that also appear in riskscan
onyphe -size 100 -maxpage 1 -search \
  'category:ctiscan cert.issuer.cn:"Major Cobalt Strike" -weekago:1
   | uniq ip.dest
   | where category:riskscan ip:$ip.dest'
```

`uniq` before `where`, never after: the correlation procs make one API call per
document. See `onyphe-opp`.

## Before a cluster is a finding

Three gates, in order. Skipping any of them is how confident wrong answers get
produced.

1. **Is it deception?** Roughly one ctiscan document in nine carries
   `tag:honeypot` — but 0.015% of ctiurl documents do, a factor of about 740, so
   run the gate once per corpus (`--base 'category:ctiurl'`) and read each
   against its own base rate. Run the candidate through the four-count check:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-hpcheck.sh" 'cert.issuer.cn:"Major Cobalt Strike"'
   # total 6  tagged 0  mp199 0  other 6  hpish 0.0   <- real
   ```
   Compare with a known emulator banner, same day:
   ```
   # app.data.text:"SSH-2.0-Paramiko"
   # total 53  tagged 22  mp199 31  other 0  hpish 100.0   <- entirely deception
   ```
   In that second case `!tag:honeypot` alone would have left 31 of 53 hosts
   looking legitimate. See `onyphe-honeypot`.

   In ctiurl the tag is weaker still: every tagged document in a measured day
   sat at `services.count:200`, so the tag says nothing a port count does not.
   Lean on the structural signals and on vhost fan-out there.

2. **Is it the provider, not the operator?** A hosting provider running its own
   service on every VPS it rents produces an attribute shared by every host in
   your cluster that has nothing to do with the operator. Check whether the
   attribute survives outside the ASN:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
     'category:ctiscan <attribute> !ip.asn:AS64496 -weekago:1'
   ```
   Use the same category here as the rarity pass that produced the attribute —
   a count and its own control must share a denominator. If that is 0, the
   attribute is locked to one provider and carries no attribution weight, and
   the query will break the moment the operator moves.

   The vhost equivalent, when the cluster came from ctiurl: compare distinct
   `ip.dest,http.hostname` against distinct `ip.dest`. Hundreds of unrelated
   names on one address is shared hosting or parking — the name does not
   attribute the address and the address does not attribute the name.

3. **Is there a second, independent indicator?** One shared attribute is
   coincidence often enough to matter. Require two that are not derived from each
   other — a certificate fingerprint and a body hash are independent; an MD5 and
   the SHA-256 of the same bytes are one indicator counted twice.

## Caveats

- Rarity is measured in a window. A value that is rare over a day may be common
  over a month; state the window with the number.
- Counts drift as the index refreshes. Re-measure rather than citing an old number.
- `onyphe-rarity.sh` skips values containing a double quote: they cannot be
  quoted safely in OQL. Pivot on a distinctive substring instead.
- `onyphe-rarity.sh` does not explode array-valued fields: `paths(scalars)`
  renders them as `tag.0`, `tag.1`, which never match the bare field name, so
  they are dropped rather than counted. The practical loss is small — the
  array-valued fields here are tag-like, and tag rarity does not signal a
  relationship between hosts the way a key or a hash does.
- Passive DNS has its own failure mode, and it is not deception: mechanical
  provider PTRs are a transform of the address applied across a whole
  allocation, so the name was never the operator's choice. Check whether a name
  embeds the address's octets before treating it as a lead.

## Cross-references

- **onyphe-oql** — which fields exist, which are populated, and the field reference.
- **onyphe-search** — counting candidates; **onyphe-export** — pulling the cluster.
- **onyphe-opp** — `uniq`, `dedup`, and the correlation procs.
- **onyphe-honeypot** — gate 1 above, in full, including why the ctiurl base
  rate is not the ctiscan one.
- **onyphe-hunt** — the methodology this sits inside.
- **onyphe-asd** — relating assets to an organisation (domains, subdomains, IPs, certificate organisations) rather than to a fingerprint.
