# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
