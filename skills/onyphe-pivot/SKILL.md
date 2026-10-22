---
name: onyphe-pivot
description: Use when the user wants to find infrastructure related to something they already have — e.g. "onyphe pivot," "find related infrastructure," "what else shares this certificate/hash/fingerprint," "onyphe rarity analysis," "which of this host's attributes are distinctive," "expand from this IP," or "unique values for this field." Covers the ctiscan pivot-field set, rarity scoring with onyphe-rarity.sh, the OPP correlation procs, and the ASD pivot-query API for server-side unique values. Not for a plain criteria search (see onyphe-search) or a single-asset lookup (see onyphe-summary).
version: 1.0.1
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

### Fields that look like pivots and are not

**JARM, JA4S, JA4T, domhash and ssdeep carry no data.** They are in the schema
and in the query builder, and `-exists:` returns 0 for every one of them over a
one-month window. A JARM pivot will return nothing, forever, without an error.

Use JA3S, the TCP fingerprint, HHHash and the response hashes instead.

## Pivoting moves

```bash
# 1. Count the candidate before pulling anything
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
  'category:ctiscan cert.fingerprint.md5:"562664f622db669088fdf3c299d910ed" -weekago:1'

# 2. Pull the cluster, projected
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-export.sh" \
  'category:ctiscan cert.issuer.cn:"Major Cobalt Strike" -weekago:1' \
  ip.dest,ip.asn,ip.organization,ip.country,tcp.dest,cert.fingerprint.md5,tag \
  data/cluster.ndjson

# 3. Distinct hosts, not documents
opp 'uniq ip.dest | addcount' < data/cluster.ndjson | tail -1

# 4. How many ASNs does it span? A cluster across several unrelated providers
#    is a stronger signal than one confined to a single hosting fleet.
jq -r '.ip.asn // empty' data/cluster.ndjson | sort -u
```

### Server-side unique values

`-asd-pivot-query` returns the distinct values of a field for a query, computed
server-side, with no paging:

```bash
onyphe -asd-pivot-query 'category:ctiscan app.device:c2 -dayago:1' -field cert.issuer.cn
# {"cert":{"issuer":{"cn":"adaptix-local"}}}
# {"cert":{"issuer":{"cn":"vigor router"}}}
# ...107 distinct values
```

Two things to know:

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
   `tag:honeypot`. Run the candidate through the four-count check:
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

2. **Is it the provider, not the operator?** A hosting provider running its own
   service on every VPS it rents produces an attribute shared by every host in
   your cluster that has nothing to do with the operator. Check whether the
   attribute survives outside the ASN:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
     'category:ctiscan <attribute> !ip.asn:AS64496 -weekago:1'
   ```
   If that is 0, the attribute is locked to one provider and carries no
   attribution weight — and the query will break the moment the operator moves.

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

## Cross-references

- **onyphe-oql** — which fields exist, which are populated, and the field reference.
- **onyphe-search** — counting candidates; **onyphe-export** — pulling the cluster.
- **onyphe-opp** — `uniq`, `dedup`, and the correlation procs.
- **onyphe-honeypot** — gate 1 above, in full.
- **onyphe-hunt** — the methodology this sits inside.
- **onyphe-asd** — relating assets to an organisation (domains, subdomains, IPs, certificate organisations) rather than to a fingerprint.
