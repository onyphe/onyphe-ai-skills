---
name: onyphe-honeypot
description: Use when an ONYPHE result needs to be checked for deception before it is believed — e.g. "is this a honeypot," "onyphe honeypot check," "validate this indicator," "is this population real," "false positive check," "why does this banner match so many hosts," or "how much of this is deception." Covers the measured honeypot base rates in ctiscan and ctiurl, the control population that actually works, the four-count validation procedure, and the structural signals that beat banner matching. Consult before any ONYPHE population count becomes a finding. Not for running the underlying query (see onyphe-search).
version: 1.1.0
---

# onyphe-honeypot

## When to use

Use this skill before reporting that a population of hosts runs a product, is
operated by an actor, or shares tradecraft. Also whenever a banner match returns
a suspiciously round or suspiciously large number.

Honeypots deliberately reproduce real product banners. A single header, title or
response hash is therefore **not product identity** — it is the one thing an
emulator is built to get right.

## The base rate

Measured 2026-09-25, one-day window:

```
category:ctiscan -dayago:1               229 980 327
category:ctiscan tag:honeypot -dayago:1   25 769 626      = 11.2%
```

**Roughly one ctiscan document in nine is already tagged as deception**, before
any hunting begins. `tag:honeypot` outnumbers every other threat tag in ctiscan
by four orders of magnitude — `compromised` is 6 275, `webshell` is 176.

Any statement of the form "N hosts run X" that has not accounted for this is
wrong by an unknown margin, usually upward.

## The base rate does not transfer to ctiurl

Measured 2026-10-29, one-day window:

```
category:ctiurl -dayago:1                25 287 230
category:ctiurl tag:honeypot -dayago:1        3 894      = 0.015%
category:ctiscan -dayago:1               214 531 635
category:ctiscan tag:honeypot -dayago:1   24 321 936      = 11.3%
```

**11.3% against 0.015% — a factor of about 740.** Carry the ctiscan base rate
into a ctiurl result and you will read an ordinary population as suspiciously
clean, or an alarming one as unremarkable. Quote each corpus against its own
rate, and run the gate once per corpus:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-hpcheck.sh" '<fragment>'
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-hpcheck.sh" '<fragment>' --base 'category:ctiurl'
```

The gap is not evidence that ctiurl is cleaner. ctiurl documents are reached by
*name*, from certificate transparency, live TLS and extracted hostnames — and an
emulator fleet that nobody points a hostname at never enters that corpus in the
first place. Low ctiurl deception is a property of how the corpus is built, not
a property of the hosts in it.

### In ctiurl the tag is nothing but a port count

The ctiscan blind spot below is a gap in the tagging. In ctiurl it is the whole
of it. Measured the same day:

| `services.count` | Total | Tagged | **Untagged** |
|---:|---:|---:|---:|
| 150 | 97 | 0 | 97 |
| 198 | 4 | 0 | 4 |
| **199** | **4 094** | 0 | **4 094** |
| 200 | 3 894 | 3 894 | **0** |
| 201 | 0 | 0 | 0 |

`category:ctiurl tag:honeypot !services.count:200 -dayago:1` returns **0**. Every
tagged ctiurl document in the window sits at exactly 200 ports — the tag adds
nothing that the port count does not already say. The ctiscan control is
577 496, so ctiscan tagging does draw on other evidence; ctiurl tagging does not.

Two consequences:

- The untagged 199 fleet (4 094) is **larger than the entire tagged population**
  (3 894). In ctiurl, `!tag:honeypot` alone discards less than half the deception
  you can actually identify.
- Anything a port count cannot see is invisible to the tag here. A ctiurl
  `hpish 0.0` is a weaker statement than the same number in ctiscan, and the
  structural signals further down carry correspondingly more weight.

## `!tag:honeypot` is not a control population

The tagging has a sharp, measurable blind spot. `services.count` — the number of
open ports on the host — caps at 200, and the tagging boundary sits exactly there:

| `services.count` | Total | Tagged | **Untagged** |
|---:|---:|---:|---:|
| 150 | 62 266 | 0 | 62 266 |
| 198 | 34 922 | 0 | 34 922 |
| **199** | **25 366 992** | 406 595 | **24 960 397** |
| 200 | 25 360 359 | 25 360 359 | **0** |
| 201 | 0 | 0 | 0 |

Read the two middle rows together. At 200 ports, **100%** of documents are
tagged. At 199 — one port below — **98.4% are not**, and there are 24.9 million
of them a day. The neighbouring bucket at 198 is 700 times smaller, so 199 is not
a natural population: it is the same emulator fleet, one port under the line.

So the control population is:

```
!tag:honeypot !services.count:199
```

Filtering only on `!tag:honeypot` leaves ~25 million deception documents a day in
what you are calling clean data.

## The four-count check

For any candidate indicator, measure how much of its population is deception
before deciding it is a finding:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-hpcheck.sh" '<OQL fragment>'
```

The default base is `category:ctiscan`; `--base` replaces it wholesale, so the
ctiurl run is a second invocation rather than a wider one. Four credits per
candidate **per base**.

| Column | Query | Means |
|---|---|---|
| `total` | the fragment | whole population |
| `tagged` | `+ tag:honeypot` | already known deception |
| `mp199` | `+ !tag:honeypot services.count:199` | the fleet the tagging misses |
| `other` | `+ !tag:honeypot !services.count:199` | genuinely new population |

`hpish = (tagged + mp199) / total`.

Under `--base 'category:ctiurl'` the columns still compute, but read `mp199`
differently: `services.count` is a host-level field that the URL documents of
that host inherit, so the column is measuring the same 200-port fleet seen
through a different corpus. A `0` there is the control not transferring, not a
clean result.

Two real candidates, same day, same window:

```
cert.issuer.cn:"Major Cobalt Strike"
  total 6    tagged 0    mp199 0    other 6    tag% 0.0     hpish 0.0

app.protocol:ssh app.data.text:"SSH-2.0-Paramiko"
  total 53   tagged 22   mp199 31   other 0    tag% 41.5    hpish 100.0
```

The first is real infrastructure. The second is entirely deception — and note
that 31 of its 53 hosts carry no honeypot tag at all. Judged on `tag%` alone it
would have looked 58% legitimate. The `mp199` column is the whole point.

### High hpish is not the only failure

A **low** hpish with a large `other` is not yet a pass. It means the candidate
found a new population, which then has to be characterised:

- **Hosting/cloud ASNs, on implausible ports, few distinct organisations** →
  emulator fleet the tagging has not reached.
- **Consumer or telecom ISPs, on the protocol's standard port, many
  organisations** → real devices. The candidate is matching a product, not an
  actor.
- **ctiurl only: many unrelated `http.hostname` values on few `ip.dest`** →
  shared hosting or parking. The names are real and the hosts are real; neither
  attributes the other. This is the ctiurl analogue of a provider fleet
  artefact, and it is the control to reach for when `mp199` reads 0.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-export.sh" \
  'category:ctiscan <fragment> !tag:honeypot !services.count:199 -dayago:1' \
  ip.dest,ip.asn,ip.organization,tcp.dest,services.count,tag \
  data/residual.ndjson

# profiling a ctiurl residual: add the vhost, and read fan-out as the
# shared-hosting control that mp199 cannot give you here
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-export.sh" \
  'category:ctiurl <fragment> !tag:honeypot !services.count:199 -dayago:1' \
  ip.dest,ip.asn,ip.organization,tcp.dest,services.count,http.hostname,tag \
  data/residual_ctiurl.ndjson

opp 'uniq ip.dest | addcount'               < data/residual_ctiurl.ndjson | tail -1
opp 'uniq ip.dest,http.hostname | addcount' < data/residual_ctiurl.ndjson | tail -1

jq -r '.ip.organization // empty' data/residual.ndjson | sort | uniq -c | sort -rn | head
jq -r '.tcp.dest // empty'        data/residual.ndjson | sort | uniq -c | sort -rn | head
```

This step is what separates a shippable signal from a plausible one, and it does
not automate — a human reads the residual.

### Zero is never a pass

`total: 0` means the candidate matched nothing. That is **inconclusive**, not
clean. `onyphe-hpcheck.sh` exits 2 on it deliberately. Before concluding
anything, confirm the field is populated (`-exists:`), the dialect is right, and
the window is wide enough — see `onyphe-search`.

Silence is not safety.

## Structural signals beat banner matching

Content can be copied byte for byte. Structure is harder to fake, and these
signals need no regex:

1. **Sprawling service footprint.** `services.count >= 150` — a host does not
   legitimately answer on 150+ ports. Prefer 150 to 200 so the 199 fleet is
   caught.
2. **One response hash across more than one ASN.** A cloned template deployed
   across unrelated providers. Catches whole families at once.
3. **The same exact response on many ports of one IP.** A real host runs
   different software on different ports.
4. **`Date`, `Last-Modified` and `Expires` identical to the second** — the page
   was generated at scan time.
5. **A protocol banner on a port belonging to a different protocol** — SSH
   answering on 5432, 1433, 3389 or 9200.
6. **Two conflicting server identities in one response** — a body claiming one
   product inside headers claiming another.

An exact-banner hash is only usable when its *content* is implausible on a real
host: a protocol violation, an unsubstituted template placeholder, a game page.
A byte-perfect copy of a genuine banner matches the genuine hosts too.

## Strip ONYPHE's own normalisation tokens first

Stored responses have scan-time values substituted out, so identical pages on
different hosts hash identically. The placeholders are:

```
<srcip>   <hostname>   <ip>
```

These are **ONYPHE's**, not the emulator's. Matching one is equivalent to
matching `/./` and tells you nothing about the target. Strip them before any
feature extraction, clustering or hashing. A ruleset built on them looks
brilliant and means nothing.

## Product identity needs more than one signal

A worked case from this tree:

- **Clone farms.** A full-page corpus of one e-commerce product surfaced 811
  hosts across 699 IPs serving copies of one real storefront — reproducing 100%
  of the plain markup markers and 0% of the runtime tokens and product-specific
  headers. A truncated corpus hides this entirely.

The rule that falls out of it: **pair a content marker with a structural one**
before asserting a product is installed, and deduplicate by host before quoting
any population.

## Caveats

- The base rate and the 199 figures drift. Re-measure rather than citing these;
  the commands are above.
- `tag:honeypot` has false positives of its own. A tagged host is a strong prior,
  not a proof.
- `-regexp:` does not work against full-text fields such as `app.data.text`.
  Validate non-HTTP candidates with a phrase match or `app.data.md5`.
- `-regexp:` is anchored and case-insensitive: write patterns lowercase, wrapped
  in `.*` for substrings.
- The ctiscan/ctiurl split above was measured on 2026-10-29; the `services.count`
  table in the ctiscan section dates from 2026-09-25. Both drift — re-measure
  rather than citing them.
- Unless a section says otherwise these figures are ctiscan. datascan has its own
  honeypot population (3 513 291 tagged on the same day) and its own field names.
- Resolver has no honeypot gate and needs none: a passive-DNS document is a name
  and an address, with no banner to emulate. Its failure mode is
  non-attributable naming — mechanical provider PTRs, shared hosting, parked
  domains — which `onyphe-hunt` phase 2c gates separately.

## Cross-references

- **onyphe-search** — the four causes of a zero result, before calling one clean.
- **onyphe-pivot** — rarity scoring; this skill is gate 1 of its three.
- **onyphe-oql** — field types, regexp limits.
- **onyphe-hunt** — where this runs as a mandatory phase, once per corpus.
