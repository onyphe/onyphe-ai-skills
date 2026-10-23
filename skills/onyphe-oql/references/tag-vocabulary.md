# Tag vocabulary

`tag` is the most portable field in ONYPHE — it keeps its name across every
category — and the fastest route from "show me something interesting" to a
bounded query. It is also the field most likely to be used on the wrong
category.

Counts are measured **2026-09-25** on one-day windows, except where a section
states its own date and window — the open-directory section below was measured
**2026-10-23**. Re-measure rather than trust any of them; see the last section.

## Tags do not live in every category

The risk and vulnerability vocabularies are **not in ctiscan**. Querying them
there returns 0 with no error:

| Tag | in `ctiscan` | in its own category |
|---|---:|---|
| `risk::criticalcve` | 0 | `category:riskscan` → 499 717 |
| `risk::exposeddatabase` | 0 | `category:riskscan` → 2 440 133 |
| `risk::vpnserver` | 0 | `category:riskscan` → 1 728 990 |
| `vulnerable` | 0 | `category:vulnscan` → 38 056 |
| `maybevulnerable` | 0 | `category:vulnscan` → 787 |
| `notvulnerable` | 0 | `category:vulnscan` → 2 114 829 |

If a hunt needs risk or CVE context on a host found in ctiscan, pivot the IP
into the other category rather than adding the tag to the ctiscan query:

```bash
onyphe -count -search 'category:riskscan ip:203.0.113.10 -weekago:1'
onyphe -count -search 'category:vulnscan ip:203.0.113.10 tag:vulnerable -weekago:1'
```

Note those categories use the **datascan** field model — `ip`, not `ip.dest`.

## What ctiscan tags actually look like

From a 3000-document sample, most frequent first:

| Tag | Meaning |
|---|---|
| `cert::notexpired` / `cert::expired` | Certificate validity window |
| `cert::valid` / `cert::notvalid` | Chain validates, or does not |
| `top1m`, `umbrella`, `majestic`, `global500`, `fortune500` | The host is on a popularity or corporate ranking list |
| `cdn`, `cloud`, `incapsula` | Hosting/fronting classification |
| `admin`, `login`, `needauth`, `sso` | The response is an authentication surface |
| `error`, `closed`, `forbidden`, `notfound`, `badrequest`, `unavailable`, `badgateway` | Response disposition |
| `proxy`, `tor`, `vpn` | Network role |
| `open` | Service accessible without authentication |
| `opendir` | The response is a directory listing |
| `file`, `file::exec`, `file::apk` | The listing exposes files / executables / Android packages |
| `suspicious::file`, `suspicious::file::creds`, `suspicious::malware` | Listing contents judged suspicious; `::creds` is credential material |
| `botnet`, `botnet::murdoc`, `mozi` | Named botnet attribution |
| `default` | Stock, unconfigured content |
| `secret`, `secret::aws`, `secret::aws::key`, `secret::aws::id` | Credential material found in the response |
| `obsolete`, `obsolete::iis` | End-of-life software |
| `honeypot` | Deception infrastructure |

## Threat tags, and how thin they are

Measured over one day in `category:ctiscan`:

| Tag | Count | Read as |
|---|---:|---|
| `honeypot` | 25 769 626 | Dominates everything. See below. |
| `open` | 574 376 | Unauthenticated service |
| `secret::aws` | 162 543 | Leaked AWS credential material |
| `vpn` | 120 477 | |
| `scanning` | 21 572 | The host is scanning others |
| `compromised` | 6 275 | |
| `tor` | 1 402 | |
| `ransomware` | 1 304 | |
| `miner` | 524 | |
| `webshell` | 176 | |
| `malware`, `botnet`, `rat`, `backdoor` | 1–2 each | Thin on a one-day window — but see below, `malware` is usable weekly |
| `phishing`, `c2`, `scanner`, `vulnerable` | 0 | Not a ctiscan tag at all |

Two consequences:

1. **Do not hunt C2 with `tag:c2`.** It returns 0. Use `app.device:c2`
   (22 391 over a week) or a certificate/fingerprint pivot.
2. **`rat` and `backdoor` are not usable as selectors** in ctiscan. Their
   single-digit counts mean absence of the tag says nothing about absence of the
   behaviour.

**Widen the window before writing a tag off.** Measured 2026-10-23,
`category:ctiscan tag:malware` is 1 document on `-dayago:1` but **28 on
`-weekago:1`** — and every one of those 28 also carries `mozi`, making it a
clean, specific Mozi selector rather than a dead tag. `tag:botnet` /
`tag:botnet::murdoc` behave the same way (4 each per day). A one-day count is a
sampling artefact for any tag in this range, not a verdict on the tag.

## The honeypot tag dwarfs the rest

`tag:honeypot` covers **25 769 626 of 229 980 327** ctiscan documents in a day —
**11.2%**. It is larger than every other threat tag combined by four orders of
magnitude.

That figure is the reason a population count is not a finding. It also has a
known blind spot: the tagging stops one port short of a very large emulator
fleet, so `!tag:honeypot` is **not** a clean control population. See
`onyphe-honeypot` for the control that works and the four-count procedure that
measures it.

## Open directories: `opendir`, not `open`

Measured **2026-10-23**. `tag:open` is too broad to hunt with in ctiscan —
573 582 documents a day. The selector you want is `opendir`:

| Tag | `ctiscan` docs/day | |
|---|---:|---|
| `open` | 573 582 | Any unauthenticated service |
| `opendir` | 94 663 | A directory listing specifically |
| `file` | 952 457 | Response exposes files |
| `file::exec` | 917 890 | …including executables |
| `file::apk` | 40 271 | …including Android packages |
| `suspicious::file` | 42 | |
| `suspicious::file::creds` | 42 | Credential material in the listing |
| `suspicious::malware` | 14 | |

In **`ctiurl`** the distinction does not matter: `tag:open` is 63 396/day and
`tag:opendir` 62 477, a 98% overlap. In `ctiscan` it matters a great deal.

Intersections are small enough to read by hand, which makes them good alert
candidates (one-week windows):

```bash
category:ctiscan tag:opendir tag:suspicious::malware -weekago:1   # 25 docs / 15 hosts
category:ctiscan tag:opendir tag:webshell            -weekago:1   # 147 docs / 77 hosts
category:ctiscan tag:suspicious::file::creds         -weekago:1   # 334 docs / 185 hosts
category:ctiscan tag:opendir tag:compromised         -weekago:1   # 148 docs / 78 hosts
```

Pair these with `extract.file` (keyword, 6 049 423 docs/day), which indexes the
filenames pulled out of the listing. Note values appear both bare (`shell.php`)
and path-prefixed (`/shell.php`), so an exact match can miss — add `-wildcard:`
when completeness matters.

Excluding popularity-ranking tags is a cheap noise filter on these:
`tag:opendir tag:webshell !tag:top1m !tag:umbrella !tag:majestic` keeps 121 of 147.

### `hpish` 0% is not a clean bill of health here

All four queries above return `hpish 0.0%` from `onyphe-hpcheck.sh` — zero
overlap with `tag:honeypot`. That is too clean to be evidence: these threat tags
and `honeypot` appear to be assigned mutually exclusively upstream, so the check
is not independent for this family of selectors. See `onyphe-honeypot`.

What discriminated in practice was **`services.count` shape**:

- **Plausible operator box** — `services.count` 2–4, SSH present, one high
  staging port, no ranking-list tags.
- **Likely decoy or shared host** — `services.count` ≥ 6, `top1m`/`umbrella`
  present, a different and inconsistent `html.title.raw` on each port.

A host advertising a C2 panel in its page title *and* sitting on the top-1M
rankings is making a claim about itself that the rest of its profile does not
support. Treat the title as a lead, never as identity.

### Count distinct hosts, not documents

`category:ctiscan extract.file:bins.sh -weekago:1` returns 4 746 documents and
looks like a major cluster. It is **10 hosts**, and 4 733 of those documents are
a single honeypot sprayed across hundreds of ports. Always
`opp 'uniq ip.dest | addcount'` before quoting a population from this family.

## Severity, for triage ordering

Roughly, when sorting what to look at first:

- **Act on** — `compromised`, `ransomware`, `webshell`, `miner`,
  `suspicious::malware`, `suspicious::file::creds`, `botnet::*`, `mozi`,
  `secret::aws::key`, `risk::criticalcve` (in riskscan), `vulnerable` (in vulnscan)
- **Investigate** — `open`, `opendir`, `file::exec`, `file::apk`,
  `suspicious::file`, `admin`, `login`, `needauth`, `obsolete::iis`,
  `risk::exposeddatabase` (in riskscan)
- **Reclassify, do not escalate** — `honeypot`, `scanning`, `tor`, `vpn`,
  `proxy`, `cdn`, `cloud`. These change what the host *is*; they are not
  findings about an adversary.
- **Context only** — `top1m`, `umbrella`, `majestic`, `fortune500`, `cert::*`

## Discovering the current vocabulary

Tags change. To re-measure rather than trust this page:

```bash
onyphe -size 1000 -maxpage 3 -search 'category:ctiscan -exists:tag -dayago:1 -fields:tag' \
  | jq -r '.tag // empty | if type=="array" then .[] else . end' \
  | sort | uniq -c | sort -rn
```
