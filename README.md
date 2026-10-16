# ONYPHE AI Skills

Skills for the [ONYPHE](https://www.onyphe.com) CLI, packaged as a Claude Code
plugin, for three jobs: **threat hunting**, **attack surface discovery (ASD)**
and **attack surface management (ASM)**. They turn a request into the right CLI
commands, and guard against the usual traps (honeypots, empty fields, mixed
field models, and treating "no result" as "safe").

An ONYPHE subscription with API access is required; every command runs against
your own API key.

## Install

Clone the repository, register it as a plugin marketplace, then install the
plugin:

```bash
git clone https://github.com/onyphe/onyphe-ai-skills.git
claude plugin marketplace add ./onyphe-ai-skills
claude plugin install onyphe
```

**Install it as a plugin.** Copying `skills/onyphe-*` into `~/.claude/skills/`
or a project `.claude/skills/` will appear to work and will not: the skills
reference their helper scripts through `${CLAUDE_PLUGIN_ROOT}`, which is only
set for an installed plugin, and both advisory hooks are wired through
`hooks/hooks.json`, which a bare skill directory does not carry.

### Prerequisites

The ONYPHE CLI, 4.20.1 or later:

```bash
onyphe -version     # ONYPHE Version: 4.20.1
```

Source and install instructions: <https://github.com/onyphe/cli>.

`jq` is required by the helper scripts. `opp` ships with the CLI.

### Authenticate

The API key lives in `~/.onyphe.ini` and is referenced, never copied:

```ini
api_endpoint = https://www.onyphe.io/api/v2
api_key = YOUR_KEY
```

(`www.onyphe.io` is the API host; `www.onyphe.com` is the website and
documentation.)

Confirm what the key can actually do before anything else:

```bash
./scripts/onyphe-preflight.sh ctiscan ctiurl
```

(From an installed plugin the skills call this as
`${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-preflight.sh`; the relative form above is
for running it by hand from a clone.)

This prints the view, history depth, authorised categories and authorised OQL
functions. The key itself is filtered out of the output and is never written to
a file.

## Skills

| Layer | Skills | Purpose |
|---|---|---|
| **Command** | onyphe-search, onyphe-export, onyphe-summary, onyphe-pivot, onyphe-timeline, onyphe-alert, onyphe-asd, onyphe-asm | Turn a request into the right CLI mode, flags and output handling. |
| **Reference** | onyphe-oql, onyphe-opp, onyphe-honeypot | Query language and field model; the OPP pipeline; deception and false-positive discipline. Consulted by the others. |
| **Methodology** | onyphe-hunt, onyphe-asd-discover, onyphe-asm-assess | Multi-step work: the threat hunt; seeds to a reviewed inventory; inventory to a prioritised risk and CVE assessment. |

- [onyphe-search](skills/onyphe-search/SKILL.md) — query and count. Counting is exact and costs one credit.
- [onyphe-export](skills/onyphe-export/SKILL.md) — full populations past the 10 000-result ceiling.
- [onyphe-summary](skills/onyphe-summary/SKILL.md) — one IP/domain/hostname across categories, and batch triage.
- [onyphe-pivot](skills/onyphe-pivot/SKILL.md) — rarity scoring and infrastructure pivoting.
- [onyphe-timeline](skills/onyphe-timeline/SKILL.md) — change over time, and the retention cliff.
- [onyphe-alert](skills/onyphe-alert/SKILL.md) — turn a validated hunt into a standing monitor.
- [onyphe-oql](skills/onyphe-oql/SKILL.md) — OQL syntax, the 216-field ctiscan model, dialect translation.
- [onyphe-opp](skills/onyphe-opp/SKILL.md) — the OPP pipeline, inline and standalone.
- [onyphe-honeypot](skills/onyphe-honeypot/SKILL.md) — deception base rates and the validation procedure.
- [onyphe-hunt](skills/onyphe-hunt/SKILL.md) — the full methodology.
- [onyphe-asd](skills/onyphe-asd/SKILL.md) — one ASD pivot: subdomains, IPs, certificate organisations.
- [onyphe-asd-discover](skills/onyphe-asd-discover/SKILL.md) — seeds to a reviewed `inventory.txt`.
- [onyphe-asm](skills/onyphe-asm/SKILL.md) — run the Discovery API on an inventory against riskscan and vulnscan.
- [onyphe-asm-assess](skills/onyphe-asm-assess/SKILL.md) — prioritised risks and CVEs, with a seven-month trend.

## Attack surface quick start

```bash
# 1. Discover assets from a seed you are entitled to assess
./scripts/onyphe-asd-run.sh web-subdomain-domain example.com
# ...review the candidates, write the accepted ones to inventory.txt as
#    domain:"example.com" / hostname:"www.example.com" / ip:"192.0.2.10"

# 2. Validate the file (a malformed line returns unrelated results, not an error)
./scripts/onyphe-inventory-check.sh inventory.txt

# 3. Risks and CVEs on those assets, over the last three months
onyphe -discovery riskscan 'inventory.txt tag:risk::exposeddatabase -since:3M -fields:ip,port,tag,seen_date'
./scripts/onyphe-asm-count.sh vulnscan inventory.txt 3M vulnerable cisa::kev
```

riskscan is generated from ONYPHE's ctiscan data, so it has the broadest and
deepest scan coverage, and keeps about **seven months** of history. vulnscan
holds CVE detections with a verdict tag. An asset with no result is **not
shown to be safe**: it may not have been scanned in the window.

## Scripts

| Script | Cost | Does |
|---|---|---|
| `onyphe-preflight.sh` | 1 | Licence, credits, authorised categories and functions. Redacts the key. |
| `onyphe-count.sh` | 1 | Exact server-side total for an OQL query. |
| `onyphe-export.sh` | varies | Streams NDJSON with a mandatory `-fields:` projection. |
| `onyphe-rarity.sh` | 1 per attribute | Rarity table for one host's pivotable attributes. |
| `onyphe-hpcheck.sh` | 4 | Four-count deception validation for a candidate indicator. |
| `onyphe-asd-run.sh` | 1 ASD call | One passive ASD pivot. Refuses live-DNS tools without `--allow-live-dns`; redacts the key. |
| `onyphe-inventory-check.sh` | 0 | Validates `inventory.txt` before it is sent to `-discovery`. |
| `onyphe-asm-count.sh` | 1 per tag | Tag-by-tag documents and distinct assets for an inventory in riskscan or vulnscan. |

## Hooks

All advisory, all always exit 0.

- `check-credit-burn.sh` — warns on `-search` without an explicit `-maxpage`
  (the default comes from `~/.onyphe.ini`, which the CLI installer writes as
  `api_maxpage = 1000`), on `-export` without `-fields:`, and when a count would
  have scoped a query first.
- `check-category-fields.sh` — warns when a query mixes the datascan and
  ctiscan field dialects. This is the highest-value check in the package: the
  mistake returns **0 with no error**.
- `check-asd-live.sh` — warns on live-DNS ASD tools (`-asd-dns-*`), on the ASM
  Inventory API (`-asm-inventory-*`, and `delall` in particular), on on-demand
  scanning, and on `-discovery` calls with no `-since:` or `-fields:`.

## Costs

Credit figures below apply to metered licences. **Griffin View licences have
unlimited credits**; there the figures only translate into request volume. The
API runs at roughly one request per second on every licence, so a long hunt is
minutes of wall clock.

| Operation | Credits |
|---|---|
| `-count -search` | 1, exact, uncapped |
| `-search` | 1 per page |
| `-summary` / `-simple` | 1 |
| `-export` | varies with volume — bound it with `-fields:` |
| Rarity table | 1 per attribute value (typically 15–30) |
| Deception check | 4 per indicator |
| Full hunt | typically 40–150 |

On a metered licence the biggest cost risk is `-maxpage` inherited from config.
Set it explicitly on every `-search`.

## Things worth knowing

Each skill carries the command behind its numbers, so all of these can be
re-checked against your own key.

- **Field names differ by category.** A datascan field under `category:ctiscan`
  returns 0 with no error: `data:"Apache"` → 0, `app.data.text:"Apache"` → millions.
- **Some ctiscan schema fields carry no data**, including JARM, JA4S, JA4T,
  domhash and ssdeep. A pivot built on one returns 0 silently.
- **Honeypots are common** — roughly one ctiscan document in ten is tagged — and
  `!tag:honeypot` is not a clean control population: untagged emulators exist.
  Use `onyphe-hpcheck.sh` before trusting an indicator.
- **The Summary API never returns ctiscan or ctiurl.**
- **ctiscan retention is about two months.** Older windows return 0.
- **The licence function list is necessary, not sufficient.** A function listed
  by `onyphe -user` can still be refused at query time; check it with a 1-credit
  count before building on it.
- **Count documents and hosts separately.** One host often has several
  documents, so a document count overstates the infrastructure.

## Not covered

- The ASM Inventory API (`-asm-inventory-*`). It changes data held in your ONYPHE
  ASM Edition environment. This package keeps the inventory in a local `inventory.txt`
  and checks it with `-discovery` instead.
- On-demand scanning (`-ondemand-*`), which originates live scans against provided 
  targets.
- Live DNS ASD tools (`-asd-dns-*`) are covered, but only with explicit opt-in per
  run: ONYPHE sends the lookups for the domains you give it.

## Security

The API key is referenced, never copied — no skill, script or hook in this
package reads, echoes or writes one. See [SECURITY.md](SECURITY.md) for the
detail, for how to report an issue, and for the live-DNS and on-demand scanning
boundary.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), including how to run the tests
(`bash tests/run-all.sh`; no network or API key needed).

## License

BSD 3-Clause — see [LICENSE](LICENSE), the same license as the
[ONYPHE CLI](https://github.com/onyphe/cli), which is distributed separately
and not included here. Use of the ONYPHE API is subject to your ONYPHE
subscription agreement.

## Support

Questions about this package: <contact@onyphe.io>, or open an issue.
For the ONYPHE service, your licence or your credit balance, contact ONYPHE
support.
