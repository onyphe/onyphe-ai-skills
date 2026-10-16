---
name: onyphe-hunt
description: >-
  Use when the user explicitly asks for a multi-step ONYPHE investigation —
  e.g. "onyphe hunt," "onyphe investigate," "hunt for related infrastructure,"
  "deep dive into this cluster with onyphe," "full onyphe investigation," or
  "/onyphe-hunt." This is a heavyweight methodology skill: a typical hunt
  spends 40-150 credits and takes several minutes at ONYPHE's ~1 request per
  second. Do NOT fire on a single lookup like "what does onyphe know about this
  IP" (use onyphe-summary) or a single query (use onyphe-search). Runs a fixed
  baseline, then branches on what the baseline shows, with a mandatory
  deception gate before anything is called a finding. Always confirms scope and
  estimated cost with the user before starting.
version: 1.0.0
---

# onyphe-hunt

> **Field names follow the category.** `ctiscan` and `ctiurl` use the ctiscan
> data model; every other category uses the datascan one. A field from the wrong
> model returns 0 with no error. When you carry a value from a summary or datascan
> result into a ctiscan query, translate the field name first
> ([map](../onyphe-oql/references/datascan-ctiscan-map.md)).

## When to use

Fires on explicit multi-step investigation requests — work that needs a
methodology across several ONYPHE calls, not one query. Typical triggers:

- "hunt for infrastructure related to 203.0.113.10"
- "onyphe investigate this certificate"
- "find the rest of this cluster"
- "full onyphe investigation on this ASN"

**Not** for "what's on this IP" (`onyphe-summary`), a single query
(`onyphe-search`), or "is this a honeypot" (`onyphe-honeypot`).

**Before starting:** confirm the target, the estimated credit cost, and whether
the user wants the full methodology or a lighter pass. A baseline alone is
roughly 15–30 credits; a hunt with two or three pivot branches is 40–150.
Griffin View licences have unlimited credits, so there the figures only
translate into request volume and wall-clock time.

**Precedence:** where this skill disagrees with a command skill
(`onyphe-search`, `onyphe-export`, `onyphe-oql`…), the command skill wins. They
own the facts about their own behaviour; this skill owns the method.

## Phase 0 — Preflight

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-preflight.sh" ctiscan ctiurl
```

Read three things off it and carry them through the whole hunt:

- **Categories.** If ctiscan is absent, this methodology does not apply.
  If datascan is absent, the hunt cannot go back further than ctiscan retention.
- **History depth.** Sets the widest defensible window.
- **Functions.** `?` OR, condition groups and regexp are licence-gated, and the
  list is necessary but not sufficient — a listed function can still be refused
  at query time. Verify the ones this hunt depends on with a 1-credit count.

## Phase 1 — Scaffold

```
YYYY-MM-DD_description/
├── data/            raw NDJSON, nothing deleted
├── analysis/
│   └── findings.md  initialised from references/findings-template.md
└── src/             any throwaway scripts
```

Three layers, deliberately: `findings.md` holds conclusions, `data/` holds
observations, and the commands in this skill are what connects them. Someone
should be able to re-derive the conclusion from the directory alone.

## Phase 2 — Baseline

```bash
# What ONYPHE holds across every category (datascan-model, NOT ctiscan)
onyphe -summary ip <TARGET> > data/summary_<TARGET>.ndjson

# The ctiscan view, which the summary does not include
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:ctiscan ip.dest:<TARGET> -weekago:1'
onyphe -size 100 -maxpage 1 -search \
  'category:ctiscan ip.dest:<TARGET> -weekago:1
   -fields:ip.dest,ip.asn,ip.organization,ip.country,tcp.dest,services.count,services.port,
app.protocol,app.device,app.tls,component.product,component.cpe,cert.subject.cn,cert.issuer.cn,
cert.fingerprint.md5,ja3s.fingerprint.md5,tcp.fingerprint.md5,http.header.data.md5,
favicon.data.md5,hhhash.fingerprint.md5,dns.reverse.hostname,tag,seen_date' \
  > data/ctiscan_<TARGET>.ndjson
```

The summary and the ctiscan search are **both** required. Summary never returns
ctiscan documents — reporting only the summary understates the host by an entire
data model.

Populate *Host profile* and *Services* in `findings.md`.

## Phase 3 — Indicator extraction and rarity

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-rarity.sh" <TARGET> --window -weekago:1 \
  > data/rarity_<TARGET>.tsv
```

Classify every value by population (see `onyphe-pivot` for the bands): unique at
1, useful at 2–25, shared tooling at 25–1000, library-or-provider above that.

Two things that look like tradecraft and are not:

- **A stack fingerprint.** JA3S and the TCP fingerprint routinely sit in the tens
  of millions. They identify a TLS library or an OS, never an operator.
- **A provider fleet artefact.** A hosting provider running its own service on
  every VPS it rents gives every host in your cluster a shared attribute. Test it:
  ```bash
  "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
    'category:ctiscan <attribute> !ip.asn:<the host ASN> -weekago:1'
  ```
  If that returns 0, the attribute is locked to one provider. Drop it — it
  carries no attribution weight and the query dies the moment the operator moves.

Populate *Indicator triage*.

## Phase 4 — Deception gate (mandatory)

Run **every** surviving indicator through the four-count check before it goes
into a pivot:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-hpcheck.sh" '<indicator fragment>' --window -weekago:1
```

About one ctiscan document in nine is already tagged as deception, and
`!tag:honeypot` alone is not a control — see `onyphe-honeypot` for why, and for
what to do with a low-`hpish` candidate that still needs its residual profiled.

This phase is not optional and not reorderable. Pivoting on an unvalidated
indicator produces a large, confident, wrong cluster.

## Phase 5 — Pivot

For each indicator that survived phase 4, in rarity order:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" 'category:ctiscan <indicator> -weekago:1'

"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-export.sh" \
  'category:ctiscan <indicator> -weekago:1' \
  ip.dest,ip.asn,ip.organization,ip.country,tcp.dest,services.count,app.device,cert.fingerprint.md5,tag \
  data/pivot_<name>.ndjson

opp 'uniq ip.dest | addcount' < data/pivot_<name>.ndjson | tail -1
jq -r '.ip.asn // empty' data/pivot_<name>.ndjson | sort -u
```

Decision trees for what to do with each shape of result are in
[references/decision-trees.md](references/decision-trees.md).

**Two independent indicators before a host joins the cluster.** Independent
means not derived from each other — a certificate fingerprint and a body hash
qualify; the MD5 and SHA-256 of the same bytes are one indicator counted twice.

## Phase 6 — Time

Once the cluster is defined, establish whether it is growing, and how far back
the evidence actually goes:

```bash
for n in 6 5 4 3 2 1 0; do
  printf '%s\t' "$n"
  "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
    "category:ctiscan <indicator> -dayago:$n"
done
```

Probe the retention edge before reading any decline as real — ctiscan returns 0
from about two months back regardless of what was there. See `onyphe-timeline`.

## Phase 7 — Persist

If the cluster is worth watching, propose an alert — and confirm the query,
recipient and threshold with the user before creating it. See `onyphe-alert`.

## Data preservation

Everything goes in `data/`, nothing is deleted.

```
data/summary_<ip>.ndjson
data/ctiscan_<ip>.ndjson
data/rarity_<ip>.tsv
data/pivot_<name>.ndjson
data/hpcheck_<name>.tsv
```

**A zero-result query is a finding and is kept.** Record the query and the four
exclusions that make the zero meaningful — dialect, `-exists:`, window, licence.
An unrecorded zero gets re-run by the next person at the same cost.

## Findings template

Initialise `analysis/findings.md` from
[references/findings-template.md](references/findings-template.md) at the start,
not the end. Every section is populated or explicitly marked N/A before the hunt
is called complete.

## Reporting

Three rules, all of which exist because the opposite has produced wrong answers:

1. **Distinct hosts, not documents.** One IP contributes many documents. Quote
   `uniq ip.dest` counts, and say which you are quoting.
2. **State the window with every number.** "6 hosts" is meaningless; "6 documents
   in a one-day window on 2026-09-25" can be checked.
3. **Say what you did not exclude.** If the residual was not profiled, if only
   one indicator was confirmed, if the window was shorter than asked for —
   say so in the findings, not in a footnote.

## Cost

| Phase | Credits |
|---|---|
| 0 Preflight | 1 |
| 2 Baseline | 3–5 |
| 3 Rarity | 15–30 (one per attribute value) |
| 4 Deception gate | 4 per indicator |
| 5 Pivot | 2–10 per branch |
| 6 Time | 1 per bucket |

A focused hunt is 40–60 credits. A broad one with several branches exceeds 150.
At roughly one request per second, that is minutes of wall clock, not seconds.

## Cross-references

- **onyphe-search** — counting, sampling, and the four reasons a zero is not an absence.
- **onyphe-export** — pulling a cluster past the 10 000-result ceiling.
- **onyphe-summary** — phase 2, and what it does not cover.
- **onyphe-pivot** — phases 3 and 5 in detail.
- **onyphe-honeypot** — phase 4 in full.
- **onyphe-timeline** — phase 6, and the retention cliff.
- **onyphe-alert** — phase 7.
- **onyphe-oql** — field names and the dialect trap, consulted throughout.
- **onyphe-opp** — deduplicating and analysing everything in `data/`.
- **onyphe-asd-discover** / **onyphe-asm-assess** — when the target is the user's own asset inventory rather than an unknown actor.
