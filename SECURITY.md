# Security

## Reporting an issue

Report security issues in this package to **contact@onyphe.io**. Please do not
open a public issue for anything that would put a user's API key or data at
risk.

Issues in the ONYPHE CLI itself belong upstream, at
<https://github.com/onyphe/cli>. Issues in the ONYPHE service belong to ONYPHE
support.

## How this package handles your API key

**The API key is referenced, never copied.**

- Authentication is delegated entirely to the ONYPHE CLI's own configuration
  file, `~/.onyphe.ini`. No skill, script or hook in this package reads, echoes,
  copies or writes an API key.
- No file in this package contains a key. The only occurrence of `api_key` is
  the placeholder `YOUR_KEY` in the README.
- `scripts/onyphe-preflight.sh` wraps `onyphe -user` and strips the key from the
  response (`jq 'del(.apikey)'`) before anything is printed. Its output is safe
  to paste into a ticket in that respect — but note it does include your own
  licensee name from your `/user` response.
- Every call goes through the `onyphe` binary. Nothing here makes a direct HTTP
  request, so there is no second code path that could mishandle a credential.

## Scanning and ethics

This package queries ONYPHE's existing scan data. It does not scan anything itself.

Two things go beyond reading existing data, and both are bounded:

- **ASD live DNS.** The `-asd-dns-*` tools make ONYPHE send DNS lookups for the
  domains you supply. They are opt-in per run: `onyphe-asd-run.sh` refuses them
  without `--allow-live-dns`, the skills ask first, and an advisory hook warns on
  a direct call. Use them only for domains you are authorised to assess.
- **Inventories.** `onyphe-asd-discover` and `onyphe-asm-assess` work on assets the
  user is entitled to assess. They do not take a target list from the internet.

On-demand scanning (`-ondemand-*`) and the ASM Inventory API (`-asm-inventory-*`)
remain **out of scope**: the first originates scans against third parties, the
second modifies account data, and `-asm-inventory-delall` removes all of it. If
you extend the package, keep that boundary: a skill reachable by a
natural-language request should not originate traffic to a third party without an
explicit, per-run confirmation.

ASD uses a separate key (`api_asd_key`, with `api_asd_endpoint`) in
`~/.onyphe.ini`, and ASD sends it as a query-string parameter. An ASD URL
therefore contains the key: never print, log or paste one. `onyphe-asd-run.sh`
redacts it.

## Published indicators

The worked examples in this package cite real indicators observed in ONYPHE data
during its development — certificate fingerprints, issuer names, ASNs and
fingerprint hashes from a command-and-control cluster. These are published
deliberately, as the evidence for the claims made around them, and are ordinary
threat-intelligence indicators. They are not exploit material and no host is
identified by address.
