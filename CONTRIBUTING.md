# Contributing

## Running the tests

```bash
bash tests/run-all.sh
```

The suites put a fake `onyphe` on `PATH` and **never touch the network**, so
they cost nothing and need no API key. A test that requires a live call does not
belong in this directory.

Scripts are also checked with:

```bash
bash -n scripts/*.sh scripts/lib/*.sh hooks/*.sh tests/*.sh
shellcheck -x --source-path=tests scripts/*.sh scripts/lib/*.sh hooks/*.sh tests/*.sh
claude plugin validate .
```

## The one rule that matters

**Every measured number carries the command that produced it.**

This package makes a lot of numeric claims — population counts, base rates,
field coverage, credit costs. Each one exists because it was measured, and each
one will drift. A number without a reproducible command beside it is an
assertion, and an assertion in a skill file becomes an assertion in an
investigation report. If you add a figure, add the `onyphe -count -search '…'`
that produced it and the date you ran it.

The corollary: if you cannot measure it, do not state it. "Not currently
visible" and "does not exist" are different claims, and only the first is
supportable from a zero result.

## Style

- Skill frontmatter is exactly `name`, `description`, `version`.
- A `description` lists the literal phrasings that should route to the skill,
  and ends with an explicit negative clause naming the skills that should be
  used instead.
- Body order: **When to use → Invocation → Common patterns → Interpreting
  results → Error handling → Caveats → Cross-references**.
- Scripts are referenced as `${CLAUDE_PLUGIN_ROOT}/scripts/…`, never by
  relative path.
- Prose examples use RFC 5737 documentation addresses (`203.0.113.0/24`,
  `198.51.100.0/24`). Real observed indicators appear only where they are the
  evidence for a claim.
- Shell is `bash`, `set -euo pipefail`, three-space indent.

## Adding a skill

A new skill needs a routing eval under `evals/<case>/` — a `prompt.md` holding
one natural-language turn, and one or more graders under `graders/`. If a skill
cannot be distinguished from its neighbours by a one-line prompt, its
`description` is not specific enough yet.

## Reporting a problem

See [SECURITY.md](SECURITY.md) for anything security-related. For everything
else, open an issue with the query you ran, the output you got, and the output
you expected.
