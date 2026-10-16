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

## vulnscan

```bash
onyphe -count -search 'category:vulnscan'                        # 1 937 956 945
onyphe -count -search 'category:vulnscan tag:vulnerable'         #       442 558
onyphe -count -search 'category:vulnscan tag:maybevulnerable'    #         4 010
onyphe -count -search 'category:vulnscan tag:notvulnerable'      #    58 118 534
onyphe -count -search 'category:vulnscan tag:unknownversion'     #    21 631 692
```

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
