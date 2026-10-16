# Tag vocabulary

`tag` is the most portable field in ONYPHE — it keeps its name across every
category — and the fastest route from "show me something interesting" to a
bounded query. It is also the field most likely to be used on the wrong
category.

All counts below measured **2026-09-25**, one-day windows.

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
| `malware`, `botnet`, `rat`, `backdoor` | 1–2 each | Effectively unused in ctiscan |
| `phishing`, `c2`, `scanner`, `vulnerable` | 0 | Not a ctiscan tag at all |

Two consequences:

1. **Do not hunt C2 with `tag:c2`.** It returns 0. Use `app.device:c2`
   (22 391 over a week) or a certificate/fingerprint pivot.
2. **`malware`, `botnet`, `rat` and `backdoor` are not usable as selectors** in
   ctiscan. Their single-digit counts mean absence of the tag says nothing about
   absence of the behaviour.

## The honeypot tag dwarfs the rest

`tag:honeypot` covers **25 769 626 of 229 980 327** ctiscan documents in a day —
**11.2%**. It is larger than every other threat tag combined by four orders of
magnitude.

That figure is the reason a population count is not a finding. It also has a
known blind spot: the tagging stops one port short of a very large emulator
fleet, so `!tag:honeypot` is **not** a clean control population. See
`onyphe-honeypot` for the control that works and the four-count procedure that
measures it.

## Severity, for triage ordering

Roughly, when sorting what to look at first:

- **Act on** — `compromised`, `ransomware`, `webshell`, `miner`,
  `secret::aws::key`, `risk::criticalcve` (in riskscan), `vulnerable` (in vulnscan)
- **Investigate** — `open`, `admin`, `login`, `needauth`, `obsolete::iis`,
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
