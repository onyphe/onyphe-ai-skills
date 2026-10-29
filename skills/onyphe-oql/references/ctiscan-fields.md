# ctiscan / ctiurl field model

Every field in the ctiscan schema, with its type and **how many documents
carried it in a one-day window, measured 2026-09-25** on a Griffin View licence.
`ctiurl` uses this same model; `http.hostname` — the virtual host that was
scanned — is what distinguishes a ctiurl document from a ctiscan one. (`http.url`
is present in both and does not discriminate: 176 124 460 ctiscan documents carry
it.)

> **Every count below was measured under `category:ctiscan` alone.** The
> regeneration loop at the end of this file is where that is baked in. The
> *model* is shared with ctiurl; the *numbers* are not, and a field that looks
> dead here can be universal there.
>
> `http.hostname` is the worked example. Measured 2026-10-29 on the same licence:
>
> ```bash
> onyphe -count -search 'category:ctiscan -exists:http.hostname -dayago:1'   #       1 455
> onyphe -count -search 'category:ctiurl  -exists:http.hostname -dayago:1'   #  25 287 226
> onyphe -count -search 'category:ctiurl -dayago:1'                          #  25 287 230
> ```
>
> 0.0007% of ctiscan, 99.99998% of ctiurl. Reading the 1 455 below as "this field
> is not worth pivoting on" is the mistake this box exists to prevent.

The count column is the point of this table. 47 of the 216 schema fields
returned **exactly zero** - they exist in the query builder and in the published
model, but carry no data. A hunt built on one of them can never match, and the
query will not error to tell you so.

## Fields that exist but carry no data

Do not build a signal on any of these. All 216 schema fields were counted over
a one-day window; every one of the 47 below was then re-counted over a one-month
window and returned zero again. This is not a quiet week - the fields carry no
data.

As above, this was measured under `category:ctiscan`. The claim is not known to
extend to `category:ctiurl`, and was not re-run there.


- `app.data.raw`
- `app.raw`
- `app.redirect`
- `cert.issuer.an`
- `cert.serial.dec`
- `cert.serial.long`
- `component.raw`
- `domhash.fingerprint.md5` - No DOM-structure pivot is available.
- `domhash.fingerprint.raw`
- `domhash.fingerprint.sha256`
- `entity.md5`
- `favicon.data.type`
- `ftp.anonymous`
- `http.body.data.raw`
- `http.body.data.text` - Body full-text lives in `app.data.text`; the body `.text` twin is empty.
- `http.header.data.text`
- `ja4s.fingerprint.md5` - JA4S/JA4T likewise - use JA3S.
- `ja4s.fingerprint.raw`
- `ja4t.fingerprint.md5`
- `ja4t.fingerprint.raw`
- `jarm.cipherversion`
- `jarm.fingerprint.md5` - JARM is in the schema but unpopulated; `ja3s.fingerprint.md5` returned 581816163 over the same month and is the working TLS pivot.
- `jarm.fingerprint.raw`
- `jarm.ja3s.md5`
- `jarm.ja3s.raw`
- `jarm.tlsextsha256`
- `scope.raw`
- `scope.text`
- `scope.type`
- `services.domain`
- `services.protocol` - Use `app.protocol` for the protocol of this document's service.
- `services.raw`
- `services.service`
- `services.text`
- `ssdeep.fingerprint.md5` - No fuzzy-hash pivot is available.
- `ssdeep.fingerprint.raw`
- `ssdeep.fingerprint.sha256`
- `ssh.fingerprint.raw`
- `tcp.raw`
- `tcp.text`
- `tlssession.ciphersuite`
- `uri.dest`
- `uri.hostname`
- `uri.raw`
- `uri.scheme`
- `uri.url`
- `uri.userinfo`

The practical consequence: **JA4S, JA4T, JARM, domhash and ssdeep are not
available as pivots.** JA3S, the TCP fingerprint, HHHash, HASSH and the response
hashes are.

## Populated fields, by layer

### Host identity and network (`ip.*`)

The document's own IP, its ASN/org/subnet and geolocation. `ip.dest` is the scanned address; the `l*` variants are the logical/registered values where they differ.

| Field | Type | Docs/day |
|---|---|---|
| `ip.asn` | keyword | 229819248 |
| `ip.country` | keyword | 229980188 |
| `ip.dest` | ip | 229980327 |
| `ip.lasn` | keyword | 229794218 |
| `ip.latitude` | float | 229980188 |
| `ip.lcountry` | keyword | 229853794 |
| `ip.llatitude` | float | 228583187 |
| `ip.llongitude` | float | 228583187 |
| `ip.longitude` | float | 229980188 |
| `ip.lorganization` | keyword | 229853794 |
| `ip.lsubnet` | keyword | 229853794 |
| `ip.netname` | keyword | 226024733 |
| `ip.organization` | keyword | 229819211 |
| `ip.src` | ip | 219093351 |
| `ip.subnet` | keyword | 229980092 |
| `ip.ttl` | short | 229977635 |
| `ip.version` | byte | 229980327 |

### TCP layer (`tcp.*`)

Port and TCP-stack fingerprint. `tcp.dest` is the port this document is about.

| Field | Type | Docs/day |
|---|---|---|
| `tcp.cpe` | keyword | 213298503 |
| `tcp.dest` | integer | 226082982 |
| `tcp.fingerprint.md5` | keyword | 226082182 |
| `tcp.fingerprint.raw` | keyword | 226082182 |
| `tcp.options` | keyword | 226082182 |
| `tcp.product` | keyword | 213298503 |
| `tcp.rtt` | float | 226082982 |
| `tcp.src` | integer | 215196006 |
| `tcp.vendor` | keyword | 213298503 |
| `tcp.window` | integer | 226082182 |

### Host service footprint (`services.*`)

Every open port found on the host, not just this document's. `services.count` is the footprint size - central to honeypot triage.

| Field | Type | Docs/day |
|---|---|---|
| `services.count` | integer | 189748131 |
| `services.port` | integer | 189748131 |

### Application response (`app.*`)

The raw response and its hashes. `app.data.text` is the full-text body, up to ~1 MB. `app.device` carries the device/threat class.

| Field | Type | Docs/day |
|---|---|---|
| `app.data.length` | integer | 226084533 |
| `app.data.md5` | keyword | 229979986 |
| `app.data.mmh3` | integer | 226084533 |
| `app.data.sha256` | keyword | 226084533 |
| `app.data.text` | text | 229979986 |
| `app.device` | keyword | 229979688 |
| `app.protocol` | keyword | 229980327 |
| `app.text` | text | 138117 |
| `app.tls` | boolean | 229980327 |
| `app.transport` | keyword | 229980327 |

### HTTP (`http.*`)

Status, URL, headers and body, each with its own hash set.

| Field | Type | Docs/day |
|---|---|---|
| `http.body.data.md5` | keyword | 172466088 |
| `http.body.data.mmh3` | integer | 172466088 |
| `http.body.data.sha256` | keyword | 172466088 |
| `http.code` | short | 176117881 |
| `http.defang` | keyword | 176146532 |
| `http.header.contentlength` | unsigned_long | 133325317 |
| `http.header.cookie` | keyword | 11892536 |
| `http.header.data.md5` | keyword | 176124135 |
| `http.header.data.mmh3` | integer | 176124135 |
| `http.header.data.raw` | keyword | 176124423 |
| `http.header.data.sha256` | keyword | 176124135 |
| `http.header.etag` | keyword | 14995425 |
| `http.header.lastmodified` | keyword | 18191231 |
| `http.header.location` | keyword | 11619817 |
| `http.header.realm` | keyword | 14336167 |
| `http.header.server` | keyword | 90849835 |
| `http.header.wwwauthenticate` | keyword | 5907202 |
| `http.hostname` | keyword | 1176 |
| `http.undefang` | keyword | 176146532 |
| `http.url` | keyword | 176124460 |
| `http.version` | keyword | 176095881 |

### HTML metadata (`html.*`)

Title, description, keywords, copyright. `.text` is full-text searchable; `.raw` is exact and regexp-able.

| Field | Type | Docs/day |
|---|---|---|
| `html.copyright.raw` | keyword | 972347 |
| `html.copyright.text` | text | 972347 |
| `html.description.raw` | keyword | 3973804 |
| `html.description.text` | text | 3973804 |
| `html.keywords.raw` | keyword | 1883704 |
| `html.keywords.text` | text | 1883704 |
| `html.title.raw` | keyword | 78597346 |
| `html.title.text` | text | 78597346 |

### TLS certificate (`cert.*`)

Subject and issuer DN components, serial, validity and fingerprints.

| Field | Type | Docs/day |
|---|---|---|
| `cert.domain` | keyword | 91806482 |
| `cert.fingerprint.md5` | keyword | 113074647 |
| `cert.fingerprint.sha1` | keyword | 113074647 |
| `cert.fingerprint.sha256` | keyword | 113074647 |
| `cert.host` | keyword | 60642904 |
| `cert.hostname` | keyword | 60642904 |
| `cert.idomain` | keyword | 21805240 |
| `cert.issuer.c` | keyword | 88342907 |
| `cert.issuer.cn` | keyword | 111305027 |
| `cert.issuer.dn` | keyword | 112564065 |
| `cert.issuer.e` | keyword | 3704746 |
| `cert.issuer.l` | keyword | 15465974 |
| `cert.issuer.o` | keyword | 89642235 |
| `cert.issuer.ou` | keyword | 17172168 |
| `cert.issuer.st` | keyword | 15302186 |
| `cert.serial.hex` | keyword | 112585096 |
| `cert.serial.num` | long | 112585096 |
| `cert.subject.an` | keyword | 76162806 |
| `cert.subject.c` | keyword | 33301143 |
| `cert.subject.cn` | keyword | 111359161 |
| `cert.subject.dn` | keyword | 112249908 |
| `cert.subject.e` | keyword | 3419995 |
| `cert.subject.l` | keyword | 26759038 |
| `cert.subject.o` | keyword | 35103362 |
| `cert.subject.ou` | keyword | 15013041 |
| `cert.subject.st` | keyword | 27545330 |
| `cert.tld` | keyword | 91806482 |
| `cert.validity.expired` | boolean | 104107416 |
| `cert.validity.valid` | boolean | 113039166 |

### Product identification (`component.*`)

CPE, vendor, product, version. Port-level, like every ctiscan field except `services.port`.

| Field | Type | Docs/day |
|---|---|---|
| `component.count` | integer | 219103906 |
| `component.cpe` | keyword | 219103906 |
| `component.distribution` | keyword | 12823921 |
| `component.patch` | keyword | 1057466 |
| `component.product` | keyword | 219103906 |
| `component.text` | text | 219190102 |
| `component.vendor` | keyword | 219190102 |
| `component.version` | keyword | 35928711 |

### DNS (`dns.*`)

Forward and reverse names attached to the host.

| Field | Type | Docs/day |
|---|---|---|
| `dns.domain` | keyword | 91745722 |
| `dns.forward.domain` | keyword | 894 |
| `dns.forward.host` | keyword | 812 |
| `dns.forward.hostname` | keyword | 812 |
| `dns.forward.idomain` | keyword | 91 |
| `dns.forward.tld` | keyword | 894 |
| `dns.host` | keyword | 89616919 |
| `dns.hostname` | keyword | 89616919 |
| `dns.idomain` | keyword | 67344555 |
| `dns.reverse.domain` | keyword | 91745388 |
| `dns.reverse.host` | keyword | 89616623 |
| `dns.reverse.hostname` | keyword | 89616623 |
| `dns.reverse.idomain` | keyword | 67344506 |
| `dns.reverse.tld` | keyword | 91745388 |
| `dns.tld` | keyword | 91745722 |

### TLS fingerprints (`ja3s.*`)

JA3S server fingerprint.

| Field | Type | Docs/day |
|---|---|---|
| `ja3s.fingerprint.md5` | keyword | 101665158 |
| `ja3s.fingerprint.raw` | keyword | 101665158 |

### SSH (`ssh.*`)

Host key fingerprints, plus the HASSH algorithm fingerprint.

| Field | Type | Docs/day |
|---|---|---|
| `ssh.fingerprint.md5` | keyword | 2213836 |
| `ssh.fingerprint.sha1` | keyword | 2213836 |
| `ssh.fingerprint.sha256` | keyword | 2213836 |

### HTTP header-order hash (`hhhash.*`)

Fingerprints the order and set of response headers, independent of their values.

| Field | Type | Docs/day |
|---|---|---|
| `hhhash.fingerprint.md5` | keyword | 171962592 |
| `hhhash.fingerprint.raw` | keyword | 171962592 |
| `hhhash.fingerprint.sha256` | keyword | 171962592 |
| `hhhash.version` | byte | 171962592 |

### Favicon (`favicon.*`)

Icon bytes and hashes - a durable pivot when the page body changes.

| Field | Type | Docs/day |
|---|---|---|
| `favicon.data.length` | integer | 10886976 |
| `favicon.data.md5` | keyword | 10886976 |
| `favicon.data.mmh3` | integer | 10886976 |
| `favicon.data.sha256` | keyword | 10886976 |
| `favicon.url` | keyword | 16446349 |

### Web trackers (`tracker.*`)

Analytics and ad IDs. A shared tracker ID is a strong operator pivot.

| Field | Type | Docs/day |
|---|---|---|
| `tracker.fbq` | keyword | 50022 |
| `tracker.ga` | keyword | 769459 |
| `tracker.gaw` | keyword | 25186 |
| `tracker.gpub` | keyword | 17202 |
| `tracker.gtm` | keyword | 151540 |
| `tracker.newrelic` | keyword | 5583 |
| `tracker.snaptr` | keyword | 444 |

### Named entities (`entity.*`)

Organisation-like strings extracted from the response.

| Field | Type | Docs/day |
|---|---|---|
| `entity.count` | integer | 229960036 |
| `entity.raw` | keyword | 229960036 |
| `entity.text` | text | 229960036 |

### Extracted indicators (`extract.*`)

URLs, hostnames, IPs and filenames pulled out of the response body.

| Field | Type | Docs/day |
|---|---|---|
| `extract.domain` | keyword | 51440728 |
| `extract.file` | keyword | 6049423 |
| `extract.hostname` | keyword | 51632022 |
| `extract.ip` | ip | 5101512 |
| `extract.url` | keyword | 51876338 |

### Redirects (`redirect.*`)

| Field | Type | Docs/day |
|---|---|---|
| `redirect.dest` | keyword | 12990927 |
| `redirect.src` | keyword | 6274424 |
| `redirect.type` | keyword | 12990927 |

### Scan provenance (`scanner.*`)

Which vantage point produced the document.

| Field | Type | Docs/day |
|---|---|---|
| `scanner.country` | keyword | 229980327 |
| `scanner.lcountry` | keyword | 229980327 |
| `scanner.name` | keyword | 229980327 |

### datascan compatibility (`compat.*`)

Mirrors of datascan field names, provided so a datascan-shaped query can be ported with less rewriting.

| Field | Type | Docs/day |
|---|---|---|
| `compat.device.class` | keyword | 229979688 |
| `compat.device.product` | keyword | 5685355 |
| `compat.device.productvendor` | keyword | 10119364 |
| `compat.device.productversion` | keyword | 941202 |
| `compat.device.productversionpatch` | keyword | 696 |
| `compat.product` | keyword | 91296551 |
| `compat.productvendor` | keyword | 90784521 |
| `compat.productversion` | keyword | 32226137 |
| `compat.productversionpatch` | keyword | 928918 |

### Root-level

| Field | Type | Docs/day |
|---|---|---|
| `hassh.fingerprint.md5` | keyword | 6911221 |
| `hassh.fingerprint.raw` | keyword | 6911221 |
| `source` | keyword | 229980327 |
| `tag` | keyword | 194726099 |
| `tlssession.protocol` | keyword | 9956363 |

## Field type semantics

| Type | What you can do with it |
|---|---|
| `keyword` | Exact match, `-wildcard:`, `-regexp:`. **Not** full-text. |
| `text` | Full-text phrase match only. **No** wildcard, **no** regexp. |
| `ip` | CIDR match, but the API refuses anything broader than /16. |
| `integer` / `long` / `short` / `byte` | Exact match. |
| `boolean` | `true` / `false`. |
| `float` | Not searchable. |

The `.raw` / `.text` pairing is the one to internalise: `html.title.raw` is
exact and regexp-able, `html.title.text` is full-text. Pointing `-regexp:` at a
`.text` field does not error - it just never matches.

## Regenerating this table

The counts date from 2026-09-25 and will drift. The field list below was taken
from the ctiscan schema; the authoritative published copy is the ctiscan data
model at <https://www.onyphe.com/docs/data-models/ctiscan>.

To re-measure every row, put one field name per line in `fields.txt` and run:

```bash
while read -r f; do
  printf '%s\t' "$f"
  onyphe-count.sh "category:ctiscan -exists:$f -dayago:1"
done < fields.txt
```

One credit per field, 216 fields. Swap in `category:ctiurl` for the URL-level
view — the counts differ, sometimes by five orders of magnitude, and the table
below does not cover them.

### Measured under `category:ctiurl`

The fields the URL-level view is actually built on, one-day window, measured
**2026-10-29**. Denominator: `category:ctiurl -dayago:1` = 25 287 230.

| Field | Type | Docs/day | Share |
|---|---|---:|---:|
| `app.data.text` | text | 25 287 230 | 100% |
| `app.tls` | boolean | 25 287 230 | 100% |
| `tcp.dest` | integer | 25 287 230 | 100% |
| `http.hostname` | keyword | 25 287 226 | ~100% |
| `http.url` | keyword | 25 287 226 | ~100% |
| `http.code` | short | 25 287 226 | ~100% |
| `services.count` | integer | 25 247 777 | 99.8% |
| `extract.url` | keyword | 22 238 848 | 87.9% |
| `extract.hostname` | keyword | 22 228 055 | 87.9% |
| `extract.domain` | keyword | 22 201 266 | 87.8% |
| `tag` | keyword | 20 202 322 | 79.9% |
| `html.title.raw` | keyword | 17 210 706 | 68.1% |
| `html.title.text` | text | 17 210 706 | 68.1% |
| `cert.subject.cn` | keyword | 11 895 532 | 47.0% |
| `extract.file` | keyword | 1 994 893 | 7.9% |

To re-verify a **single** row without spending 216 credits — which is the usual
case, and the one worth doing before you trust any number here:

```bash
onyphe-count.sh 'category:ctiscan -exists:ja3s.fingerprint.md5 -dayago:1'
```

If you need the live field list rather than the one below, take it from a real
document:

```bash
onyphe -search 'category:ctiscan -dayago:1' -size 1 | jq -r 'paths(scalars) | join(".")'
```

That yields the fields populated on *that* document, not the whole schema, so it
under-reports — which is the right direction to err in. A field absent from a
sample may still exist; a field present is certainly real.

