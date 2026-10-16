# riskscan and vulnscan

All numbers measured **2026-10-16** against a Griffin View licence, each with the
command that produced it.

## Field model

Both categories use the **datascan-style** names: `ip`, `port`, `hostname`,
`domain`, `tag`, `cpe`, `seen_date`, `organization`, `asn`. A ctiscan name returns 0
with no error. vulnscan adds `cve` (array) and `cvecount`. Inside `-discovery`,
`-fields:ip,port,tag,seen_date` projects as expected.

## riskscan

Risk tags (`tag:risk::…`). Counts with no window:

```bash
onyphe -count -search 'category:riskscan tag:risk::exposeddatabase'   # 45 292 871
onyphe -count -search 'category:riskscan tag:risk::criticalcve'       #  5 514 206
```

History reaches about seven months:

```bash
onyphe -count -search 'category:riskscan -monthago:6'   # 566 984 678
onyphe -count -search 'category:riskscan -monthago:7'   # 320 531 051
onyphe -count -search 'category:riskscan -monthago:8'   # 0
```

riskscan also carries the CVE data (same detections as vulnscan, positives only):

```bash
onyphe -count -search 'category:riskscan -exists:cve'             #     5 572 606
onyphe -count -search 'category:riskscan tag:vulnerable'          #       435 927
onyphe -count -search 'category:riskscan tag:notvulnerable'       #       156 506
```

Compare vulnscan below: 5 592 604 with a `cve`, 442 558 `vulnerable`, but 58 118 534
`notvulnerable`. The two agree on positives; the negatives live in vulnscan. riskscan's
raw `data` is truncated after a period of time (the exact age is not measured here);
vulnscan keeps the full stored response.

## vulnscan

```bash
onyphe -count -search 'category:vulnscan'                        # 1 937 956 945
onyphe -count -search 'category:vulnscan tag:vulnerable'         #       442 558
onyphe -count -search 'category:vulnscan tag:maybevulnerable'    #         4 010
onyphe -count -search 'category:vulnscan tag:notvulnerable'      #    58 118 534
onyphe -count -search 'category:vulnscan tag:unknownversion'     #    21 631 692
```

```bash
onyphe -count -search 'category:vulnscan -exists:cve'            #     5 592 604
```

Only about 0.3% of vulnscan documents carry a `cve`; add `-exists:cve` to every
vulnscan Discovery call.

### vulnscan verdict tags

Meanings are from ONYPHE's tag documentation
(<https://search.onyphe.io/docs/tags/vulnscan>); counts measured 2026-10-16 with
`onyphe -count -search 'category:vulnscan tag:<tag>'`.

| Tag | Kind | Meaning | Count |
|---|---|---|---:|
| `vulnerable` | check | The check found the device vulnerable to the CVE | 438 847 |
| `notvulnerable` | check | The check found it not vulnerable | 58 072 139 |
| `maybevulnerable` | check | May be vulnerable, not confirmed | 4 010 |
| `unknownvulnerable` | check | Check ran, result cannot decide | 16 443 908 |
| `vulnerableversion` | version | Detected version is on ONYPHE's vulnerable list | 4 925 037 |
| `notvulnerableversion` | version | Detected version is not on the list | 21 220 365 |
| `maybevulnerableversion` | version | Version may be vulnerable | 37 262 |
| `partialversion` | version | Version only partly identified, not to patch level | 725 197 |
| `unknownversion` | version | No version found | 21 483 145 |
| `version` | version | Version found, no CVE associated | 252 807 |

Check-based verdicts are a live test and the preferred evidence; version-based ones
are the fallback when no check exists. The documentation calls `unknownvulnerable`
rare, but it is populated at 16 million here, so do not treat it as negligible.
Known-exploited and ranked sets: `cisa::kev` (2 908 983), `anssi::top10`,
`nsa::top25`, `nsa::top5`, `fireeye::arsenal`, `log4shell`.

A `vulnerable` document carries `cve` and often `cisa::kev` / `onyphe::kev`
(known-exploited). History is much longer than riskscan:

```bash
onyphe -count -search 'category:vulnscan -monthago:8'    # 147 630 378
onyphe -count -search 'category:vulnscan -monthago:12'   # 111 621 171
```

## Discovery API

```bash
onyphe -discovery riskscan 'inventory.txt <OQL> -since:7M -fields:ip,port'
```

- Each inventory line → `category:<c> <line> <OQL>`; the OQL is ANDed in.
- No `-since:` → latest per asset; `-since:` → every scan in the window.
- A malformed line returns 10 000 unrelated documents, not an error.
- Test inventory of two ONYPHE-owned domains: 15 documents latest, 57 documents
  over 7M for 6 distinct `ip:port`.

Counts above are a snapshot; the commands are the reference.
