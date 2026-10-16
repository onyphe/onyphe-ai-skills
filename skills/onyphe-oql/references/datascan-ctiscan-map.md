# Translating between the datascan and ctiscan/ctiurl models

A field name from the wrong model **returns 0 with no error**. This is the
single most common reason an ONYPHE query silently finds nothing, and it is
indistinguishable from a genuine absence unless you know to look.

All figures below measured 2026-09-25, `category:ctiscan`, one-day window.

## datascan name → ctiscan/ctiurl name

| Meaning | datascan | ctiscan / ctiurl | Verified |
|---|---|---|---|
| raw application response | `data` | `app.data.text` (+ `app.data.length`) | `data:"Apache"` 0 vs `app.data.text:"Apache"` 7 663 474 |
| response hash | `datamd5` | `app.data.md5` | |
| CPE | `cpe` | `component.cpe` | `cpe:"cpe:/a:apache:http_server:-"` 0 vs `component.cpe:` 3 063 115 |
| product | `app.http.component.product` / `product` | `component.product` | |
| vendor | `app.http.component.productvendor` / `productvendor` | `component.vendor` | note: **not** `productvendor` |
| version | `app.http.component.productversion` | `component.version` | |
| HTTP status | `status` | `http.code` | `status:200` 0 vs `http.code:200` 33 224 626 |
| URL | `url` | `http.url` | |
| page title | `app.http.title` | `html.title.text` (full-text) / `html.title.raw` (exact, regexp) | `app.http.title:"index of"` 0 vs `html.title.text:` 91 744 |
| IP | `ip` | `ip.dest` | |
| port | `port` | `tcp.dest` (this service) / `services.port` (any open port on the host) | `port:443` 0 vs `tcp.dest:443` 23 194 680 |
| protocol | `protocol` | `app.protocol` | `protocol:http` 0 vs `app.protocol:http` 176 146 431 |
| device class | `device.class` | `app.device` | `device.class:c2` 0 vs `app.device:c2` 3 411 |
| HTTP body hash | `app.http.bodymd5` | `http.body.data.md5` | |
| HTTP header hash | `app.http.headermd5` | `http.header.data.md5` | |
| favicon hash | `app.favicon.imagemd5` | `favicon.data.md5` | |
| reverse DNS | `reverse` | `dns.reverse.hostname` | |
| forward DNS | `forward` | `dns.forward.hostname` | |
| ASN | `asn` | `ip.asn` | |
| organization | `organization` | `ip.organization` | |
| country | `country` | `ip.country` | |
| subnet | `subnet` | `ip.subnet` | |
| cert subject CN | `subject.commonname` | `cert.subject.cn` | |
| cert issuer org | `issuer.organization` | `cert.issuer.o` | |
| cert fingerprint | `fingerprint.sha256` | `cert.fingerprint.sha256` | |

## Fields that keep their name in both

`tag`, `source`, `@category`, `@timestamp`, `seen_date`.

`tag` is the most portable thing across the two models and often the cleanest
way to carry an idea from a datascan dork into a ctiscan hunt.

## Porting a datascan dork

The published risk dorks are written in datascan. To reuse one for hunting,
translate every field:

```
# datascan, as published
category:datascan ?protocol:telnet ?protocol:pop3 ?protocol:imap ?protocol:ftp tls:false

# ctiscan equivalent
category:ctiscan ( ?app.protocol:telnet ?app.protocol:pop3 ?app.protocol:imap ?app.protocol:ftp ) app.tls:false
```

```
# datascan
category:datascan device.class:database tag:open

# ctiscan
category:ctiscan app.device:database tag:open
```

Note the second rewrite also needs the OQLv2 group with its inner spaces, since
`?` terms that must be grouped were implicitly grouped in the flat form.

## What has no ctiscan equivalent

- **The Summary API.** `-summary ip` returns datascan, riskscan, ip, resolver,
  pastries, sniffer, topsite and whois — never ctiscan or ctiurl, even for a host
  with ctiscan documents in the same window (verified 2026-09-25). A ctiscan
  baseline has to come from a direct search.
- **`-simple ctiscan`.** There is no Simple endpoint for it.

## Why the compat layer is not a shortcut

ctiscan carries `compat.*` fields mirroring datascan names
(`compat.product`, `compat.device.class`, …). They are there to ease porting,
not to make datascan syntax work: the query-side name is still `compat.product`,
not `product`. Writing `product:x` under `category:ctiscan` still returns 0.
