# ASD tools

How each passive ASD tool behaves. Behaviours marked *measured* were run against
ONYPHE-owned domains on 2026-10-16 with the CLI; the rest are carried from
earlier hands-on validation and should be re-checked before being quoted as
numbers.

## Transport

The CLI hides this, but it explains the errors you will see.

- ASD lives on its own endpoint (`api_asd_endpoint`, with its own `api_asd_key`)
  in `~/.onyphe.ini`; without it every call fails 404.
- ASD takes the key as a **query-string parameter**, unlike the search API.
  Any URL printed from an ASD call carries the key.
- Requests are POSTs with a JSON body; responses are NDJSON.
- `aslines` is always used; `trusted` is a `0|1` switch (`-trusted`), and
  `-includep` / `-excludep` take comma-separated patterns.
- There is no paging and no limit parameter. Volume is controlled by what you
  seed, not by page size.

## Per tool

| Tool | Result key | Observed |
|---|---|---|
| `domain-tld` | `domain` | *measured*: `onyphe.net` returned `onyphe.net` only (its own input). |
| `web-subdomain-domain` | `hostname`, `domain` | *measured*: `onyphe.net` returned `www.onyphe.io`, `search.onyphe.io` and a `{"domain":"onyphe.io"}` line, i.e. it crosses to related domains. |
| `ip-domain` | `ip`, `ipv6` | *measured*: `onyphe.net` returned many IPv4 lines with `"ipv6":"false"`. |
| `certso-domain` | `subject.organization` (nested) | *measured*: error 1006 for `onyphe.net`. |
| `domain-certso` | `domain` | Certificate-organisation to domains. Noisy for shared issuers. |
| `domain-wildcard` | `domain` | `name*` fine; `*name*` hits error 2 (ASD timeout). |
| `certso-wildcard` | `subject.organization` | Substring matching; caught unrelated organisations that merely contain the string. Treat every result as a candidate. |
| `org-inventory` | `organization` | Needs IP input, or domains with `-includep`. |
| `ip-inventory` | `ip` | |
| `vhost-inventory` | `forward` | Key is `forward`. |

Not offered by the skill: `-asd-subnet-inventory` and the bootstrap certificate
wildcard call returned nothing for any input shape in earlier validation, and
`-asd-score-inventory` is a scoring call rather than a pivot.

## Live DNS family

`-asd-dns-domain-{ns,mx,soa,mstenantid,exist,ns-exist}` perform live DNS lookups
on ONYPHE's side. `exist` checks return `{"exist":"false"}` lines for non-existent
domains, whereas the passive `domain-exist` signals absence as error 1006.
