# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.0] — 2026-10-29

### Added

- `onyphe-oql` (1.3.0), `references/resolver-fields.md`: a field model for
  **`category:resolver`** (passive DNS), which had none anywhere — no plugin
  reference, no `ResolverDocument` in the OpenAPI spec, no `data-models/`
  page. All 53 fields counted individually, with the type from the published
  index template and the measurement date on every number. Documents the
  category's **Griffin View only** licence gate up front, because an
  unauthorised category returns nothing rather than erroring. Covers the
  record-type census (`type:` holds ONYPHE resolution classes — `forward`,
  `reverse`, `soa`, `ns`, `mx`, `txt`, `cname`, `spf` — so `type:a` and
  `type:ptr` match nothing), the `source:` provenance census, the 12-month
  retention ladder, and the two fields that are projectable but not filterable
  (`@category`, `seen_date`, the latter rejected outright as
  `syntax error: invalid word found`).
- `onyphe-oql` (1.3.0): a **Several categories** section documenting the
  `category:ctiscan,ctiurl` comma list, which is in production use in ONYPHE's
  own tooling but appears in no vendor documentation and is modelled as a
  single enum in the OpenAPI spec. Says so explicitly, so a reader who checks
  the spec meets the discrepancy explained. Warns against straddling the two
  field models in one list.
- `onyphe-hunt` (1.1.0): **phase 2b (vhost view)**, **phase 2c (passive DNS,
  Griffin View only)** and **phase 5b (name-keyed pivot)**. The methodology
  queried `category:ctiscan` exclusively while already authorising ctiurl in
  preflight, and never queried `category:resolver` at all — its one mention
  deferred passive DNS as future work. Phase 2c carries its own attribution
  gate (mechanical PTR, name mobility, shared-hosting density, provider
  template) because resolver's failure mode is non-attributable naming rather
  than deception, and resolver documents have no `services.*` for the honeypot
  gate to key on. Phase 6 gains a depth track and a three-way licence branch.
- `onyphe-hunt`, `references/decision-trees.md`: **Tree 7** (the target is a
  name, not an IP — shared hosting and CDN fronting) and **Tree 8** (a
  passive-DNS name was found).
- `scripts/onyphe-rarity.sh`: a `--category` flag, restricted to `ctiscan`,
  `ctiurl` and the comma list. A datascan-model category is rejected with a
  reason rather than accepted — the seed pull keys on `ip.dest` and every
  default field is a ctiscan-model name, so it would otherwise return 0 with
  no error, which in a rarity table is indistinguishable from a maximally rare
  attribute.
- `onyphe-honeypot` (1.1.0): a **ctiurl base-rate section**. The skill measured
  deception in ctiscan only, so its headline "one document in nine" was being
  applied to a corpus where the real figure is 0.015%. Adds the per-corpus
  `--base` workflow and the measured `services.count` table for ctiurl.
- `onyphe-pivot` (1.1.0): a **which-corpus-to-pivot-in** section, a vhost/URL
  pivot-field row, and a **passive-DNS pivot-field** table (Griffin View only,
  datascan dialect). Documents `-asd-pivot-query` against `category:ctiurl` with
  `-field http.hostname` as the cheapest server-side way to enumerate the
  virtual hosts on an address and tell single-tenant from shared hosting.
- `evals/resolver-fidelity-cliff/`, `evals/hunt-covers-vhosts/`: behaviour
  evals for the two new ways to be confidently wrong — reading a stripped-field
  zero as "that name never resolved here", and attributing a co-tenant's vhost
  to the target.

- `AGENTS.md`: operating instructions for AI coding agents working in this
  repository ([agents.md](https://agents.md/) convention) — setup and check
  commands, repository layout, the repository-specific rules (API key, measured
  numbers, zero-is-not-absence, the ASM Inventory / on-demand / live-DNS scope
  boundary, credit cost) and a pre-finish checklist. Opens with a **what
  ONYPHE is** primer for an agent with no prior context — OQL has no
  `AND`/`OR`/`NOT` keywords, the two field models fail silently, the API is
  metered and live, the data describes real third-party hosts including
  honeypots — then routes to `skills/onyphe-oql/`, the vendor docs, the
  OpenAPI spec and the `onyphe/material` index templates rather than
  restating them. Points at `README.md`, `CONTRIBUTING.md` and
  `SECURITY.md` for the rest.

### Changed

- `onyphe-timeline` (1.0.1): "datascan is the only way further back" was wrong
  in both directions — resolver reaches 12 months against datascan's 7, and
  neither exists on a CTI-only edition. Replaced with a three-way depth table
  keyed on preflight, and a note that resolver's depth is not uniform. The
  30-day pruning caveat now names the whole optimized set (datascan, resolver,
  riskscan, vulnscan) rather than datascan alone.
- `onyphe-hunt` (1.1.0): the phase 2 baseline and phase 5 pivot now query
  `category:ctiscan,ctiurl`; rarity (phase 3) and the deception gate (phase 4)
  deliberately do **not**, because a rarity band and an `hpish%` are both claims
  about a denominator and the two corpora differ by roughly an order of
  magnitude. Phase 5 reports distinct `ip.dest,tcp.dest,http.hostname` alongside
  distinct hosts — collapsed to `uniq ip.dest`, 40 vhosts on 3 IPs and 3 vhosts
  on 40 IPs are the same number.
- `onyphe-hunt`, `references/pivot-patterns.md`: certificate, response-hash,
  favicon, tracker and component patterns widened to the union; SSH and
  service-footprint patterns deliberately left on ctiscan, with the reason
  stated (a ctiurl document is an HTTP fetch, so `ssh.*` is definitionally
  empty there). New **Vhost and URL** and **Passive DNS names** sections. The
  file is now linked from `SKILL.md`, which it never was.
- `onyphe-pivot` (1.1.0): pivot moves now query `category:ctiscan,ctiurl` and
  report distinct `ip.dest,tcp.dest,http.hostname` alongside distinct hosts; the
  rarity bands carry an explicit warning that a band is a claim about a
  denominator and the two corpora must be scored separately; gate 1 is run once
  per corpus and gate 2 must share its rarity pass's denominator. Records that
  rarity scoring cannot be pointed at `category:resolver` at all, and the
  array-drop limitation of `onyphe-rarity.sh`.
- `onyphe-honeypot` (1.1.0): the four-count check notes that `--base` replaces
  the prefix wholesale (four credits per candidate *per base*), that `mp199`
  does not carry its ctiscan meaning elsewhere, and that vhost fan-out is the
  ctiurl control to reach for when `mp199` reads 0. Adds a caveat that resolver
  needs no honeypot gate — a passive-DNS document has no banner to emulate.
- `scripts/onyphe-hpcheck.sh`: usage text now documents `--base`, which existed
  and worked but was explained nowhere and passed by no skill.

### Fixed

- `onyphe-oql`, `references/ctiscan-fields.md`: the file said `http.url` is what
  distinguishes a ctiurl document from a ctiscan one, contradicted by its own
  table — `http.url` sits on 176 124 460 ctiscan documents. **`http.hostname`**
  is the discriminator. The file also never said that every count in it was
  measured under `category:ctiscan` alone, so `http.hostname | 1 455` read as a
  dead field when it is on ~100% of ctiurl documents. Both corrected, with a
  scope box and a new ctiurl sub-table.
- `scripts/onyphe-rarity.sh`: a comment claimed array values were exploded; they
  are silently dropped, because `paths(scalars)` renders them as `tag.0`,
  `tag.1`. Comment corrected to describe the actual behaviour and why the loss
  is tolerable (tag rarity does not signal a relationship between hosts).
  Behaviour unchanged — fixing it multiplies the credit cost and needs its own
  change.

### Measured

All on 2026-10-29, Griffin View, commands in the files that quote them.

- The comma category list returns the union, exactly:
  `category:ctiscan tag:opendir -dayago:1` 93 020 +
  `category:ctiurl tag:opendir -dayago:1` 78 050 =
  `category:ctiscan,ctiurl tag:opendir -dayago:1` 171 070.
- `http.hostname` is the ctiurl discriminator: 25 287 226 of 25 287 230 ctiurl
  documents (~100%) against 1 455 ctiscan documents a day — 0.0007%.
- Honeypot base rates are not transferable between the two corpora:
  `tag:honeypot` is 24 321 936 of 214 531 635 ctiscan documents (11.3%) but
  3 894 of 25 287 230 ctiurl documents (0.015%), a factor of ~740.
  `services.count:199` is 4 094 ctiurl documents a day, none of them tagged.
- **15 of 50 queryable resolver fields stop being searchable at 8 months** —
  `@version`, `city`, the six `company.*`, `forward`, `latitude`, `location`,
  `longitude`, `reverse`, `subnet`, `ttl`. The boundary is sharp: `reverse` is
  1 586 458 128 at `-monthago:7` and 0 at `-monthago:8`, while the `hostname`
  control holds at 9 519 355 087 and 8 030 961 463 across the same two buckets.
  This is **not** the 30 days the published retention note implies; that figure
  describes `data` truncation, not field removal. `ip:`, `hostname:`, `domain:`
  and `type:` all survive to full depth.
- Resolver retention: `-monthago:12` 883 099 652, `-monthago:13` 0.
  `-since:12M` is accepted and returns 95 972 087 957.
- Resolver provenance: `source:ctiscan` 100 444 838/day, `massdns` 69 583 544,
  `ctl` 40 652 156, `ctiurl` 36 777 156, `massdns::bruteforce` 13 423 653,
  `vulnscan` 6 144 387, `datascan` 418 795. Certificate- and vhost-derived names
  are ~29% of a day's passive DNS.
- **In ctiurl, `tag:honeypot` is nothing but a port count.**
  `category:ctiurl tag:honeypot !services.count:200 -dayago:1` returns **0** —
  every tagged document in the window sits at exactly 200 ports — against a
  ctiscan control of 577 496. The untagged 199 fleet (4 094) is larger than the
  whole tagged population (3 894), so `!tag:honeypot` alone discards less than
  half the identifiable deception there.
- Resolver record classes: `type:forward` 172 914 486/day, `reverse` 45 337 109,
  `soa` 16 022 547, `ns` 9 580 156, `mx` 9 298 588, `txt` 8 505 151,
  `cname` 5 835 635, `spf` 21 895. `type:a` and `type:ptr` both return 0.

## [1.3.0] — 2026-10-23

### Added

- `.claude-plugin/icon.png`: the ONYPHE logo as the plugin icon (900 × 900 PNG,
  transparent background), picked up from the default path without an `icon`
  field in `plugin.json`.
- `onyphe-oql` (1.2.0), `tag-vocabulary.md`: an **open directories** section.
  Hunt listings with `tag:opendir`, not `tag:open` (94 663 against 573 582
  `ctiscan` documents a day; in `ctiurl` the two overlap 98%). Adds the
  `file` / `file::exec` / `file::apk` and `suspicious::*` tags, four one-week
  intersection queries sized for alerting, `extract.file` usage (bare and
  path-prefixed values), and ranking-tag exclusion as a noise filter.
- `tag-vocabulary.md`: `hpish 0%` is not evidence for these threat tags, which
  appear never to co-occur with `honeypot`; `services.count` shape is the
  discriminator that worked. Count distinct hosts, not documents — one
  `extract.file:bins.sh` "cluster" of 4 746 documents was 10 hosts.
- `tag-vocabulary.md`: `opendir`, `file*`, `suspicious::*`, `botnet`,
  `botnet::murdoc` and `mozi` in the tag table and the triage-severity lists.

### Changed

- `tag-vocabulary.md`: `ctiscan` `tag:malware` is no longer written off as
  unusable. It is 1 document on `-dayago:1` but 28 on `-weekago:1`, every one
  also tagged `mozi` (2026-10-23). Widen the window before dismissing a tag;
  only `rat` and `backdoor` remain listed as unusable selectors.
- README: documents the one-step `/plugin install onyphe --marketplace
  onyphe/onyphe-ai-skills` route (Claude Code 2.1.275 or later) alongside the
  clone route, which is still needed for `prerequisites.sh` and
  `onyphe-preflight.sh`. The clone route registers the marketplace with
  `claude plugin marketplace add ./`.

### Fixed

- `hooks/hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}` in every hook command. Unquoted,
  an install path containing a space split into several words and the hooks
  failed to run.

## [1.2.0] — 2026-10-22

First public release.

### Added

- `prerequisites.sh`: checks `jq`, the ONYPHE CLI version and that `~/.onyphe.ini`
  exists. When the CLI is missing or too old it checks the Perl modules it needs
  (including `Net::IP`), and offers to install them and build the CLI from
  <https://github.com/onyphe/cli>. Installs nothing without a typed `y`; never
  reads the API key. The README opens with a Getting started section built on it.
- Advisory `check-oql-boolean.sh` hook: flags `OR`/`AND`/`NOT`/`||`/`&&` written as
  keywords in an OQL query. OQL has none; the API answers
  `filter not allowed: ORdomain`, which agents misread as "OR is unsupported".
- `oql-boolean-or` eval and `test-hook-boolean.sh`.
- `riskscan-vulnscan.md`: the full vulnscan verdict-tag table (check-based versus
  version-based, with counts), and the CVE counts riskscan carries.

### Changed

- The ONYPHE CLI minimum is now 4.20.2.
- `onyphe-oql` and `onyphe-search` (1.1.0) state that boolean logic is `?` (OR),
  `!` (NOT) and implicit AND, with a several-values recipe and
  `-orwildcard:` / `-notwildcard:` / `-orregexp:` / `-notregexp:` examples; the
  search error table maps the `ORdomain` signature. A one-line reminder is added
  to `onyphe-export`, `onyphe-pivot` and `onyphe-hunt` (1.0.1).
- `onyphe-asm` and `onyphe-asm-assess` (1.2.0): riskscan carries the same CVE
  detections as vulnscan, positives only; vulnscan is for evidence (the stored
  response), negative verdicts and history beyond seven months. Version-based
  `vulnerableversion` is counted and reported separately from check-based
  `vulnerable`, which alone misses most CVE-bearing records.
- `onyphe-asm-count.sh` adds `-exists:cve` to every vulnscan call, so verdicts
  without a CVE (most vulnscan documents, including `unknownversion`) drop out.
  riskscan calls are unchanged.

### Measured

- Only 5 592 604 of 1 938 348 687 vulnscan documents carry a `cve`; 4 925 037 are
  `vulnerableversion` against 438 847 `vulnerable` (2026-10-16, commands in
  `riskscan-vulnscan.md`).

### Fixed

- Added `.claude-plugin/plugin.json` and `marketplace.json`. 1.1.0 documented
  `claude plugin marketplace add` and `claude plugin install onyphe` but shipped
  without the manifests those commands need.

- `onyphe-export.sh` and `onyphe-count.sh` split OQL from an OPP pipeline at the
  first **unquoted** `|`, as the CLI does. A `|` inside a double-quoted value, such
  as the regexp alternation `-regexp:http.header.server,".*(red hat|rocky).*"`, made
  export insert `-fields:` inside the regexp: the query ran with no projection and
  a silently wrong population, and exited 0. Count refused the same query, so
  `onyphe-hpcheck.sh` could not run the deception gate on it.
- `onyphe-export.sh` ignores a `-fields:` inside a quoted value, refuses a query with
  an unclosed double quote, and re-splits the assembled query, exiting 1 unless
  `-fields:` ends the OQL part. `onyphe-count.sh` also refuses an unclosed quote,
  which would swallow the control terms `onyphe-hpcheck.sh` appends.
- The splitter is shared in `scripts/lib/oql.sh`, with `test-oql-split.sh`.

## [1.1.0] — 2026-10-16

### Added

- **Attack surface discovery (ASD)**: `onyphe-asd` (one pivot) and
  `onyphe-asd-discover` (seeds to a reviewed `inventory.txt`).
- **Attack surface management (ASM)**: `onyphe-asm` (`onyphe -discovery` on an
  inventory against riskscan and vulnscan) and `onyphe-asm-assess` (prioritised
  assessment with a seven-month trend).
- `onyphe-oql/references/riskscan-vulnscan.md`: field model, tag counts, retention.
- `onyphe-asd-run.sh`, `onyphe-inventory-check.sh`, `onyphe-asm-count.sh`, and the
  advisory `check-asd-live.sh` hook, with tests and routing evals.

### Changed

- Scope widened from hunting to hunting plus ASD and ASM. `-asd-dns-*` is now
  covered behind an explicit per-run opt-in; the ASM Inventory API
  (`-asm-inventory-*`) and on-demand scanning remain out of scope.
- `SECURITY.md` documents the live-DNS exception and ASD key handling.
- Relicensed from Apache-2.0 to BSD 3-Clause, matching the ONYPHE CLI; `NOTICE`
  removed. Copies already obtained under 1.0.0 remain under Apache-2.0.
- README rewritten for end users; Griffin View licences are documented as having
  unlimited credits, with credit figures qualified as applying to metered
  licences.
- The category-to-data-model rule (ctiscan/ctiurl = ctiscan model, every other
  category = datascan model) now opens `onyphe-oql`, `onyphe-search`,
  `onyphe-export`, `onyphe-hunt` and `onyphe-pivot`.
- `check-category-fields.sh` applies the datascan model to every explicitly named
  non-ctiscan/ctiurl category, not only `category:datascan`.

### Measured

- A malformed inventory line sent to `-discovery` returns 10 000 unrelated
  documents rather than an error (2026-10-16, riskscan).
- riskscan retention: `-monthago:7` returns documents, `-monthago:8` returns 0.

### Fixed

- Removed the claim that ctiscan `component.*` is host-level / service-aggregated
  (`onyphe-honeypot`, `onyphe-pivot`, `onyphe-hunt` pivot patterns, `onyphe-oql`
  field reference). Every ctiscan field except `services.port` is port-level, so
  the "good selector, bad population count" caveats built on it are gone.

## [1.0.0] — 2026-09-25

First public release.

### Added

Ten skills, in three layers.

**Command wrappers** — turn a request into the right CLI mode, flags and output
handling:

- `onyphe-search` — query and count. Counting is exact and costs one credit.
- `onyphe-export` — full populations past the 10 000-result Search ceiling.
- `onyphe-summary` — one IP, domain or hostname across categories, plus batch
  triage.
- `onyphe-pivot` — rarity scoring and infrastructure pivoting.
- `onyphe-timeline` — change over time, and the retention cliff.
- `onyphe-alert` — turn a validated hunt into a standing monitor.

**Reference** — consulted by the others:

- `onyphe-oql` — OQL syntax, the 216-field ctiscan model, datascan↔ctiscan
  dialect translation. Ships five reference files, including a per-field
  population table and a query cookbook with the count each query returned.
- `onyphe-opp` — the ONYPHE Processing Pipeline, inline and standalone.
- `onyphe-honeypot` — deception base rates and the four-count validation
  procedure.

**Methodology**:

- `onyphe-hunt` — the eight-phase investigation: preflight, scaffold, baseline,
  rarity, deception gate, pivot, time, persist. Ships decision trees, pivot
  patterns and a findings template.

Five helper scripts (`onyphe-preflight.sh`, `onyphe-count.sh`,
`onyphe-export.sh`, `onyphe-rarity.sh`, `onyphe-hpcheck.sh`), two advisory
`PreToolUse` hooks (credit-burn and category/field-dialect checks, both always
exit 0), seven test suites that run against a fake `onyphe` on `PATH` and never
touch the network, and thirteen routing evals.

### Notes

Every measured number in this package was taken on 2026-09-25 against a Griffin
View licence, and every one of them carries the command that produced it. They
will drift; re-measure before quoting.
