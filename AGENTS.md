# AGENTS.md

Operating instructions for AI coding agents working in this repository.
Humans should start from [README.md](README.md); this file is the short form,
plus the rules that are easy to break without noticing.

## What this repository is

`onyphe-ai-skills` is a **Claude Code plugin**: 14 skills, 8 helper scripts and
4 advisory hooks that drive the [ONYPHE CLI](https://github.com/onyphe/cli) for
threat hunting, attack surface discovery (ASD) and attack surface management
(ASM). It contains no application code — the deliverables are Markdown skill
files and `bash` scripts.

It is a *packaging* repository for operational knowledge. Most of its value is
in the measured numbers inside the skill files, so the standard of proof for a
change to prose is as high as for a change to code.

## Context: what ONYPHE is

If you have not worked with ONYPHE before, read this section before touching
anything — most of the rules below are unintelligible without it.

ONYPHE is a commercial French cyber defence search engine. It scans the whole
IPv4 space and 5000+ TCP ports from Europe, the US and Asia, fingerprints what
answers, and sells query access to the resulting data. Five facts drive
everything in this repository:

1. **Queries are written in OQL**, ONYPHE's own query language, not SQL and not
   Lucene. `category:ctiscan app.protocol:http -dayago:1 -fields:ip.dest,tag`.
   AND is implicit between filters, `?field:value` is OR, `!field:value` is NOT,
   and `-name:value` is a function. **There are no `AND` / `OR` / `NOT`
   keywords** — writing them produces an error message that reads like a licence
   problem.
2. **Categories fall into two incompatible field models.** `ctiscan` and
   `ctiurl` use layered names (`ip.dest`, `app.data.text`, `component.cpe`);
   `datascan`, `vulnscan` and `riskscan` use flat ones (`ip`, `data`, `cpe`).
   A field from the wrong model returns **0 results with no error**, which is
   indistinguishable from the thing genuinely not being there.
3. **The API is metered, rate-limited and real.** Every command in this package
   spends a request against a live paid service at roughly one per second, and
   credits on a metered licence. Access needs a subscription key, and there
   is no sandbox endpoint to experiment against — which is why the test
   suite fakes the CLI instead.
4. **The data describes third parties' real hosts**, not test fixtures. Some of
   those hosts are honeypots that deliberately imitate products, so a banner
   match is not identity — which is why this package has a whole skill about
   deception and a helper script that validates an indicator before it is
   believed.
5. **The CLI is a separate program** (<https://github.com/onyphe/cli>, Perl,
   BSD 3-Clause). It is not vendored here; this repository only drives it.

Where to get grounded, in order:

- `skills/onyphe-oql/SKILL.md` and `skills/onyphe-oql/references/` — the query
  language, the field model, the dialect map, the tag vocabulary. Read this
  before editing any skill that contains a query.
- `skills/onyphe-honeypot/SKILL.md` — why a count is not yet a finding.
- <https://search.onyphe.io/docs> — the vendor documentation.
- <https://github.com/onyphe/material/tree/master/openapi> — the OpenAPI 3.0.3
  specification of the endpoints.
- <https://github.com/onyphe/material/tree/master/datamodels> — the index
  templates, one JSON per category. The authoritative answer to "does this field
  exist?" and "is it exact-match (`keyword`) or full-text (`text`)?".

**Never invent an OQL example you cannot check against those files.** A query
that looks right and silently returns nothing is the characteristic failure of
this domain, and a skill file is the worst place for one.

## Setup and commands

```bash
bash tests/run-all.sh                   # whole suite; no network, no API key, free
bash tests/test-hook-fields.sh          # one suite
bash -n scripts/*.sh scripts/lib/*.sh hooks/*.sh tests/*.sh
shellcheck -x --source-path=tests scripts/*.sh scripts/lib/*.sh hooks/*.sh tests/*.sh
claude plugin validate .                # manifest + skill frontmatter
```

Run all four before proposing a change. There is no CI and no build step.

The tests put a fake `onyphe` on `PATH` and never reach the network. **A test
that needs a live API call does not belong in `tests/`.**

To exercise the skills for real you need an ONYPHE subscription, the CLI 4.20.2
or later, `jq`, and a key in `~/.onyphe.ini`; `./prerequisites.sh` checks all of
it, and `./scripts/onyphe-preflight.sh` reports what the key may query. Install
the plugin rather than copying `skills/` anywhere — the skills resolve their
scripts through `${CLAUDE_PLUGIN_ROOT}`, which only an installed plugin sets.

## Layout

| Path | Contents |
|---|---|
| `skills/onyphe-*/SKILL.md` | The skills. Frontmatter is exactly `name`, `description`, `version`. |
| `skills/*/references/*.md` | Long reference material a skill loads on demand. |
| `scripts/`, `scripts/lib/` | Helper scripts called by the skills. |
| `hooks/`, `hooks/hooks.json` | Advisory `PreToolUse` checks. All exit 0, always. |
| `tests/` | Offline suites, one `test-*.sh` per script or hook. |
| `evals/<case>/` | Routing and behaviour evals: `prompt.md` plus `graders/*.md`. |
| `.claude-plugin/` | `plugin.json`, `marketplace.json`, `icon.png`. |

## Rules specific to this repository

1. **Never read, echo, write or commit an API key.** No skill, script or hook
   in this package touches `~/.onyphe.ini` beyond checking that it exists, and
   script output is filtered so a key cannot leak into a transcript. Keep it
   that way. See [SECURITY.md](SECURITY.md).
2. **Every measured number carries the command that produced it, and the date.**
   A population count, base rate or credit figure without the
   `onyphe -count -search '…'` beside it is an assertion, and an assertion in a
   skill file becomes an assertion in somebody's incident report. If you cannot
   measure it, do not state it.
3. **A zero result is not an absence.** "Not currently visible" and "does not
   exist" are different claims and only the first is supportable from a zero
   count. The same goes for safety: an asset with no finding has not been shown
   to be safe. Skills must never phrase it otherwise.
4. **Respect the scope boundary.** This package deliberately does not cover the
   ASM Inventory API (`-asm-inventory-*`, which mutates account state) or
   on-demand scanning (`-ondemand-*`, which originates scans against third-party
   targets). Live-DNS ASD tools (`-asd-dns-*`) are covered only behind an
   explicit per-run opt-in (`--allow-live-dns`). Do not add coverage for the
   first two, and do not remove the opt-in on the third.
5. **Mind the credit cost of anything you suggest a user run.** Metered licences
   pay per request, the API averages one request per second, and `-maxpage`
   inherited from `~/.onyphe.ini` is the usual way to spend a lot by accident.
   Scope with a 1-credit `-count` first; set `-maxpage` explicitly; require
   `-fields:` on every `-export`.
6. **Examples use RFC 5737 documentation addresses** (`192.0.2.0/24`,
   `198.51.100.0/24`, `203.0.113.0/24`) and example domains. A real observed
   indicator appears only where it is the evidence for a claim.
7. **Field dialects are the most common failure.** A datascan field name under
   `category:ctiscan` returns 0 results with no error. Any example you add must
   use the field names of the category it queries.

## Conventions

- Shell is `bash`, `set -euo pipefail`, three-space indent. Scripts are
  referenced as `${CLAUDE_PLUGIN_ROOT}/scripts/…`, never by relative path.
- A skill `description` lists the literal phrasings that should route to it and
  ends with a negative clause naming the skills to use instead.
- Skill body order: **When to use → Invocation → Common patterns →
  Interpreting results → Error handling → Caveats → Cross-references**.
- A new skill needs a routing eval under `evals/`. If a one-line prompt cannot
  distinguish it from its neighbours, its `description` is not specific enough.
- Bump the `version` in the skill's own frontmatter when you change it, and add
  the change under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) (Keep a
  Changelog, SemVer). A release bumps `.claude-plugin/plugin.json` too.
- Commit subjects follow the existing log: `- new: …`, `- update: …`,
  `- bugfix: …` for ordinary changes, `ONYPHE AI Skills X.Y.Z: …` for a release.
- British spelling in prose, as in the existing files.

## Before you finish

- [ ] `bash tests/run-all.sh` passes, plus `bash -n`, `shellcheck` and
      `claude plugin validate .`.
- [ ] New or changed numbers carry their command and date.
- [ ] New skill has an eval; changed skill has a bumped `version`.
- [ ] `CHANGELOG.md` updated under `## [Unreleased]`.
- [ ] No key, no customer data, no real inventory committed.
- [ ] Do not commit, push, or open a pull request unless you were asked to.
