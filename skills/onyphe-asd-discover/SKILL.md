---
name: onyphe-asd-discover
description: >-
  Use when the user wants to build an asset inventory for an organisation from a
  few seeds: "discover our attack surface," "build an inventory for example.com,"
  "find everything belonging to this company," "onyphe asd discover," "map the
  external footprint of." Runs the multi-step ASD discovery loop (seeds, pivots,
  noise review) and ends with a reviewed inventory.txt. Spends one ASD call per
  step and may ask to use live DNS lookups. Do NOT fire on a single pivot (see
  onyphe-asd), on assessing risks of an existing inventory (see onyphe-asm-assess),
  or on hunting a threat actor's infrastructure (see onyphe-hunt).
version: 1.1.0
---

# onyphe-asd-discover

Turn a handful of seeds into an inventory you can defend. The output is a file,
`inventory.txt`, which `onyphe-asm` and `onyphe-asm-assess` consume.

## Before starting

Confirm with the user:

1. **The organisation and seeds**: domains, certificate subject organisations,
   or `name*` wildcards. Cap: 500 values per type; values over 256 characters are
   skipped, never truncated (a shortened domain is a different, wrong asset).
2. **Authorisation.** The inventory is a list of assets the user is entitled to
   assess. If the seeds belong to a third party, stop and say so.
3. **Live DNS.** Passive preset by default. The DNS preset sends lookups from
   ONYPHE's side; ask separately, per run.
4. **Where to save** (default `./inventory.txt`; keep seeds and raw results in
   the same directory).

## Presets

| Preset | Steps (each feeds the next) | Live DNS |
|---|---|---|
| **passive** (default) | `domain-tld` → `web-subdomain-domain` → `certso-domain` → `domain-certso` | no |
| **fast** | `domain-tld` → `dns-domain-ns` → `dns-domain-mx` → `dns-domain-soa` → `certso-domain` | **yes** |
| **certso loop** | `certso-domain` → `domain-certso` → `certso-domain` | no |
| **listings** | `ip-domain`, `web-subdomain-domain` | no |

`fast` uses live DNS, so it only runs once the user has cleared live DNS for this
run; otherwise stay on `passive`. Run each step with `onyphe-asd-run.sh`
([onyphe-asd](../onyphe-asd/SKILL.md)); a step reads the values the previous
steps produced, not their raw documents.

## The loop

1. **Seed.** Write the seeds to `seeds.txt`, one `value` per line, per type.
2. **Run a step, review, then continue.** After every step print: input count,
   output count, new distinct values. Never chain steps blindly.
3. **Explosion rule.** If a step returns more than **~300** values, stop and ask.
   A pivot that fans out past that is usually a shared certificate organisation
   or a shared DNS provider, not the target. For `certso-wildcard` the threshold
   is **10**: substring matching is the noise source.
4. **Drop known false positives** before review: shared certificate
   organisations such as Cloudflare, Salesforce, Microsoft Corporation, Apple Inc.,
   Amazon.com Inc., Edgecast, Fortinet, Plesk and cert-manager.
5. **Review.** Group candidates by pivot and ask the user to accept, reject or
   flag. A candidate nobody has accepted does not enter the inventory.
6. **Deduplicate on `filter:"value"`** and write accepted values as
   `domain:"x"`, `hostname:"x"`, `ip:"x"` or `subject.organization:"x"`.
7. **Validate**:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-inventory-check.sh" inventory.txt
   ```
   This matters beyond tidiness: a malformed line sent to `-discovery` is not an
   error. It returned 10 000 unrelated documents when tested.

## Output

Report the inventory size per type, how many candidates were rejected and why, any
step that hit the explosion rule, and which tools returned error 1006. State
plainly that a discovery run is **a lower bound**: ASD finds what ONYPHE can relate
to the seeds, not everything the organisation owns.

## Cross-references

- `onyphe-asd` — the individual tools and their quirks.
- `onyphe-asm-assess` — what to do with the finished inventory.
- `onyphe-honeypot` — if an accepted IP looks like deception infrastructure.
