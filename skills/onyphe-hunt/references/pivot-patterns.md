# Pivot patterns

Tactical patterns for phase 5. Each names the field, what it actually
identifies, and how it fails.

All populations measured 2026-09-25 on a Griffin View licence, **under
`category:ctiscan`**. The union count for the same indicator is greater than or
equal to the figure quoted.

## The patterns

### Certificate

```
category:ctiscan,ctiurl cert.fingerprint.md5:"<md5>" -weekago:1
category:ctiscan,ctiurl cert.issuer.cn:"<cn>" -weekago:1
category:ctiscan,ctiurl cert.subject.o:"<org>" -weekago:1
category:ctiscan,ctiurl cert.serial.hex:"<hex>" -weekago:1
```

The strongest routine pivot. A self-signed certificate reused across hosts is
operator choice, not infrastructure.

**Fails on:** default serials. `cert.serial.hex:"2"` returns 100 780 documents a
day — it is what a tool emits when nobody set one. Check the population before
treating a serial as an identifier.

### TLS and TCP stack fingerprints

```
category:ctiscan ja3s.fingerprint.md5:"<md5>" -weekago:1
category:ctiscan tcp.fingerprint.md5:"<md5>" -weekago:1
```

**These identify a library and an OS, not an operator.** A single JA3S value
returned 26 812 618 documents in one day; a TCP fingerprint 41 074 061. They are
useful only as a *filter* alongside something rare — never as the pivot itself.

**JARM, JA4S and JA4T are not available.** They exist in the schema; `-exists:`
returns 0 for each over a month. A JARM pivot fails silently and forever.

Left on `category:ctiscan` deliberately: both are already dismissed above as
non-attributing, so widening them to the union spends the same credit to reach
the same conclusion.

### Response and header hashes

```
category:ctiscan,ctiurl app.data.md5:"<md5>" -weekago:1
category:ctiscan,ctiurl http.header.data.md5:"<md5>" -weekago:1
category:ctiscan,ctiurl http.body.data.md5:"<md5>" -weekago:1
category:ctiscan,ctiurl hhhash.fingerprint.md5:"<md5>" -weekago:1
```

HHHash fingerprints the *order and set* of response headers independently of
their values, which makes it more durable than a header hash when content changes.

**Fails on:** empty and generic responses. One `app.data.md5` on a real C2 host
matched 16 398 668 documents — it was the hash of an empty response. Count first.
And an emulator can clone a real banner byte for byte, so a hash alone is not
product identity.

### Favicon

```
category:ctiscan,ctiurl favicon.data.md5:"<md5>" -weekago:1
category:ctiscan,ctiurl favicon.data.mmh3:"<mmh3>" -weekago:1
```

Durable across body changes — operators re-theme pages far more often than they
replace the icon.

**Fails on:** framework defaults. A stock admin-panel icon is shared by every
install of that product.

### SSH

```
category:ctiscan ssh.fingerprint.sha256:"<sha256>" -weekago:1
category:ctiscan hassh.fingerprint.md5:"<md5>" -weekago:1
```

A host key is genuinely per-host: the same key on two IPs means a shared image or
a migrated host. HASSH is the algorithm-set fingerprint — closer to a stack
fingerprint, so broad.

**ctiscan only, and necessarily.** A ctiurl document is an HTTP fetch, so
`ssh.*` and `hassh.*` are definitionally empty there. Adding `,ctiurl` costs the
same credit for a guaranteed-identical answer.

### Trackers

```
category:ctiscan,ctiurl tracker.ga:"<id>" -weekago:1
category:ctiscan,ctiurl tracker.gtm:"<id>" -weekago:1
```

A shared analytics ID is one of the strongest operator pivots available: it is an
account, registered by a person, and it survives a full re-theme.

### Components and entities

```
category:ctiscan,ctiurl component.text:<product> -weekago:1
category:ctiscan,ctiurl entity.text:<org> -weekago:1
```

Good for scoping a population, poor for attribution.

### Service-footprint shapes

```
category:ctiscan app.device:c2 services.count:1 -weekago:1
category:ctiscan ( ?services.port:8080 ) ( !services.port:80 !services.port:443 )
```

Often better than any single attribute. Purpose-built infrastructure has a
small, unusual footprint; the *absence* of the ports a normal host would have is
as informative as the presence of an odd one.

**ctiscan only**: `services.*` describes the host, and the shape logic is a
host-level idea. The URL documents of the same host inherit the field without
adding anything to the question.

### Vhost and URL

```
category:ctiscan,ctiurl http.hostname:"<name>" -weekago:1
category:ctiscan,ctiurl -wildcard:http.hostname,*.<domain> -weekago:1
category:ctiscan,ctiurl extract.domain:"<domain>" -weekago:1
```

`http.hostname` is the virtual host ONYPHE sent in the Host header, and it is
what separates the two corpora: 25 287 226 of 25 287 230 ctiurl documents carry
it, against 1 455 ctiscan documents a day (2026-10-29). Names reach ONYPHE's
scan list from certificate transparency, live TLS and `extract.hostname`, so
this pivot sees infrastructure that is addressed by name and never by IP.

`extract.domain` is a different question: domains ONYPHE pulled out of a
*response body*. A match means the actor's own page referenced the domain, which
is a link between two properties rather than between two hosts.

**Fails on two things, both badly:**

- **Shared hosting.** Hundreds of unrelated names on one `ip.dest`. The name
  does not attribute the IP and the IP does not attribute the name. Compare
  `uniq ip.dest,http.hostname` against `uniq ip.dest` before reading anything
  into a shared IP.
- **CDN fronting.** `ip.dest` is an edge node belonging to the CDN. It carries
  no attribution weight at all, and an ASN-based control will mislead you.

### Passive DNS names

```
category:resolver ip:<ip> -since:12M
category:resolver hostname:<name> -since:12M
category:resolver type:ns ( ?hostname:ns1.<domain> ) -since:7M | dedup ns | addcount
```

**Griffin View only**, and the datascan dialect (`ip:`, not `ip.dest:`).

The strongest resolver pivot is not a name at all: on `type:soa` documents,
`datamd5` hashes the raw SOA record, so two domains sharing a `datamd5` share a
DNS operator.

**Fails on:** mechanical provider PTRs, which are a transform of the IP applied
across a whole allocation and were never the operator's choice. One hunt
recorded 75 695 such documents on a single domain. Check whether the name embeds
the IP's octets before treating it as a lead.

Beyond seven months `forward` and `reverse` stop being searchable — use
`type:forward` / `type:reverse` instead. See
`onyphe-oql/references/resolver-fields.md`.

## Before you pivot on anything

### Count it

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:ctiscan,ctiurl <indicator> -weekago:1'
```

One credit, exact. Under ~25 is worth pursuing; over ~1000 is a library, a
product default or a provider.

### Test it against the provider

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
  'category:ctiscan,ctiurl <indicator> !ip.asn:<host ASN> -weekago:1'
```

If that returns 0, the attribute exists only inside one hosting provider. It is
a fleet artefact, not tradecraft, and a query built on it breaks the moment the
operator changes provider.

### Run the deception gate

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-hpcheck.sh" '<indicator>' --window -weekago:1
```

Non-negotiable. See `onyphe-honeypot`.

## Confirming membership

**Two independent indicators.** Independent means not derived from each other:

| Independent | Not independent |
|---|---|
| certificate fingerprint + body hash | MD5 and SHA-256 of the same bytes |
| SSH host key + favicon hash | `app.data.md5` and `app.data.sha256` |
| tracker ID + certificate serial | `cert.fingerprint.md5` and `.sha256` |

Report **confirmed/total** — "31 of 53 confirmed on two indicators" — rather than
the raw match count. And treat a 100% confirmation rate across a large set with
suspicion: it usually means the two indicators were the same thing twice.

## Bulk verification

Verifying N candidates is N counts, at roughly one request per second. A
50-candidate set is about a minute of wall clock and 50 credits before any pull.
Deduplicate the candidate list first:

```bash
opp 'uniq ip.dest' < data/pivot_all.ndjson | jq -r '.ip.dest' | sort -u > data/candidates.txt
```

When the pull was a union, deduplicate on `ip.dest,http.hostname` instead — one
IP can contribute many vhosts, and collapsing them hides the fan-out that
distinguishes shared hosting from an operator estate.

Never run the correlation procs (`where`, `merge`, `search`) on an
undeduplicated stream — they make one API call per document.
