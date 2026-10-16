---
name: onyphe-asd
description: Use when the user wants to discover an organisation's internet-facing assets with ONYPHE Attack Surface Discovery (ASD): find domains, subdomains, hostnames or IPs from a seed domain, certificate organisation or inventory, or run one `-asd-*` pivot. Wraps the passive `onyphe -asd-*` CLI modes. Trigger phrases include "onyphe asd," "discover assets for," "find subdomains of," "which IPs belong to this domain," "domains from this certificate organisation," "attack surface discovery," and "build an inventory from." Not for the full seed-to-reviewed-inventory process (see onyphe-asd-discover), assessing risks or CVEs on an inventory (see onyphe-asm), or distinct values of an OQL query (see onyphe-pivot).
version: 1.1.0
---

# onyphe-asd

## When to use

One ASD pivot: give ONYPHE a domain, a certificate subject organisation or an
inventory, get related assets back. Covers requests like:

- "what subdomains does example.com have"
- "which IPs belong to example.com"
- "which domains share this certificate organisation"
- "which hosting organisation runs these IPs"

Doing this repeatedly, reviewing candidates and ending with a trustworthy
`inventory.txt` is `onyphe-asd-discover`. Checking that inventory for risks and
CVEs is `onyphe-asm`.

ASD reads data ONYPHE already holds, with one exception: the `-asd-dns-*` tools
make ONYPHE perform live DNS lookups (see below).

## Invocation

Use the wrapper. It allow-lists passive tools, refuses live-DNS ones, treats "no
result" as empty, de-duplicates and redacts anything key-shaped:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-asd-run.sh" web-subdomain-domain example.com
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-asd-run.sh" ip-domain domains.txt
```

The argument is a single value or a file with one value per line. The tool name
is the CLI flag without `-asd-`. Pass exactly one tool per call.

## Tools

| Tool | Input | Returns | Notes |
|---|---|---|---|
| `domain-tld` | domain | domain | Other TLDs of the same name. |
| `domain-wildcard` | pattern | domain | `example*` works; a **leading `*`** can hit the ASD timeout (error 2). |
| `domain-certso` | certificate organisation | domain | Domains seen on certificates with that organisation. |
| `domain-exist` | domain | domain | Keeps only domains that exist. |
| `web-subdomain-domain` | domain | hostname | Output mixes `{"hostname":…}` and `{"domain":…}` lines. |
| `certso-domain` | domain | `subject.organization` | Nested in the response. |
| `certso-wildcard` | pattern | `subject.organization` | Substring matching is noisy; pass `-trusted 0` deliberately and review. |
| `ip-domain` | domain | ip | Lines are `{"ip":…,"ipv6":"false"}` (or `"true"`). |
| `ip-certso` | certificate organisation | ip | |
| `org-inventory` | inventory file | organisation | Returns nothing for domain-only input unless `-includep` is set; works from IPs. |
| `ip-inventory` | inventory file | ip | |
| `vhost-inventory` | inventory file | vhost | The response key is `forward`, not `vhost`. |

Details of each field, and what is noisy, are in
[asd-tools.md](references/asd-tools.md).

### Live DNS tools

`dns-domain-ns`, `dns-domain-mx`, `dns-domain-soa`, `dns-domain-mstenantid`,
`dns-domain-exist` and `dns-domain-ns-exist` make ONYPHE send DNS lookups for the
input domains. The wrapper refuses them unless you pass `--allow-live-dns`.

**Ask the user first, every run**, and only for domains they are authorised to
assess. Approval for one run is not approval for the next.

## Reading the results

- **Output is NDJSON, one object per line.** Do not parse it as one JSON array.
- **Error 1006 ("no result found") is an empty answer.** The CLI prints it as an
  `ERROR: ASD API call failed: 400` line; the wrapper converts it. Empty means ASD
  found nothing for this input. It does not mean the asset has no footprint.
- **The input can be echoed back.** `domain-tld` returns the input domain among
  its results; remove it before counting.
- **Every result is a candidate, not an asset.** Related by certificate, DNS or
  hosting is not the same as owned. Shared certificate organisations
  (Cloudflare, Salesforce, Microsoft, Apple, Amazon and similar) produce
  thousands of unrelated domains. Review before anything enters an inventory.

## Error handling

| Symptom | Cause and fix |
|---|---|
| `error 1006` | No result. Empty, not a failure. |
| `error 2` | ASD-side timeout, typically a leading-`*` wildcard. Anchor the pattern (`name*`). |
| `error 1011, too many results` | Re-run with `-astask 1`, then poll with `-asd-task-poll <id>`. |
| `ASD API call failed: 404` | `api_asd_endpoint` missing from `~/.onyphe.ini`. |
| Long call | A pivot over hundreds of domains can take about a minute. Wait; do not retry. |

## Caveats

- ASD authenticates with the key in the request URL. **Never print or log the
  ASD URL**, and never copy `api_asd_key` anywhere. The wrapper redacts it.
- Whether an ASD call consumes credits is **not established**: Griffin View is
  unlimited so it cannot be observed there. Do not quote an ASD credit cost.
- Pass one `-asd-*` flag per invocation; the CLI picks the mode by iterating a
  hash, so two flags give a non-deterministic choice.

## Cross-references

- `onyphe-asd-discover` — the full discovery loop and inventory review.
- `onyphe-asm` — assess the resulting inventory.
- `onyphe-pivot` — `-asd-pivot-query`, distinct values for an OQL query.
