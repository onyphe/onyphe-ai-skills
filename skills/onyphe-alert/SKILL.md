---
name: onyphe-alert
description: Use when the user wants ONYPHE to keep watching a query after the investigation ends — e.g. "onyphe alert," "monitor this query," "notify me when this changes," "set up an onyphe alert," "list my onyphe alerts," "watch for new hosts matching this," or "delete this alert." Wraps `-alert-add`, `-alert-list` and `-alert-del`. Creating or deleting an alert is a persistent, email-generating change to the account — confirm with the user before either. Not for one-off retrospective queries (see onyphe-search) or reconstructing the past (see onyphe-timeline).
version: 1.0.0
---

# onyphe-alert

## When to use

Use this skill at the end of a hunt, when a query has been validated and the
useful thing now is to be told when it matches something new — or when the user
wants to review or clean up the alerts they already have.

An alert is ONYPHE's answer to "watch this going forward". It is the counterpart
to `onyphe-timeline`, which reconstructs backward.

## Confirm before writing

`-alert-add` and `-alert-del` change account state that outlives the session, and
an alert sends email to a named address on a schedule. Neither is reversible by
re-running a command.

**Before adding:** confirm the query, the recipient address and the threshold
with the user. **Before deleting:** show the alert you are about to remove, by id
and query, and get agreement.

Listing is read-only and safe to run unprompted.

## Invocation

```bash
# Read-only
onyphe -alert-list

# Create - confirm first
onyphe -alert-add -alert-name "NAME" -alert-email "you@example.org" '<OQL>'

# Create with an explicit threshold (default is '>0')
onyphe -alert-add -alert-name "NAME" -alert-email "you@example.org" \
  -alert-threshold '>10' '<OQL>'

# Delete - confirm first
onyphe -alert-del <id>
```

`-alert-list` returns a standard envelope:

```json
{"count":0,"error":0,"results":[],"status":"ok","text":"Success","total":0}
```

The alerts themselves are in `results`; `total` is how many exist.

## What an alert is, and is not

| It is | It is not |
|---|---|
| A saved OQL query, evaluated on a schedule | A materialised set of hosts |
| An email when the match count crosses a threshold | Something you can subsequently search against |
| A way to notice new members of a known cluster | A store of what it has matched before |

There is no way to query "what did this alert match last week" — that is what
`onyphe-timeline` is for. An alert tells you *that* something changed; you then
run the query yourself to see *what*.

## Writing an alert query that will not become noise

An alert inherits every weakness of the query behind it, and then sends it to
someone by email on a schedule. Before saving one:

1. **Count it first.** A query matching 25 million documents makes an alert that
   fires forever.
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" '<OQL>'
   ```
2. **Run it through the honeypot check.** An indicator that is mostly deception
   produces an alert that is mostly deception.
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-hpcheck.sh" '<OQL fragment>'
   ```
3. **Leave the time function out.** The alert supplies its own recency; a
   `-dayago:1` baked into a saved query will age into something that means
   something else.
4. **Set a threshold that reflects the baseline.** `>0` on a query with a steady
   population of 6 fires every evaluation. Use `>0` for something that should
   normally match nothing, and a real number for something with a known floor.
5. **Name it so a stranger can act on it.** The name is most of what the
   recipient sees. `"CS team servers - new cert issuer"` beats `"alert3"`.

## Common patterns

```bash
# Review what exists
onyphe -alert-list | jq -r '.results[] | "\(.id)\t\(.name)\t\(.query)"'

# Validate a candidate before proposing it as an alert
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-count.sh" \
  'category:ctiscan cert.issuer.cn:"Major Cobalt Strike"'
"${CLAUDE_PLUGIN_ROOT}/scripts/onyphe-hpcheck.sh" \
  'cert.issuer.cn:"Major Cobalt Strike"'

# Then, after confirming with the user
onyphe -alert-add \
  -alert-name "CS team servers by issuer CN" \
  -alert-email "hunter@example.org" \
  -alert-threshold '>6' \
  'category:ctiscan cert.issuer.cn:"Major Cobalt Strike"'
```

## Error handling

| Symptom | Cause and fix |
|---|---|
| `-alert-add` rejected | Alert APIs are licence-gated. Check `onyphe-preflight.sh`. |
| Alert created but never fires | The threshold is above the population, or the saved query carries a stale time function. |
| Alert fires constantly | Population well above the threshold. Count it and re-scope rather than raising the threshold blindly. |
| `-alert-del` on an unknown id | Ids come from `-alert-list`; they are not the alert name. |

## Caveats

- One API mode per invocation — `-alert-add` cannot be combined with a search.
- The query is stored as written. A field name that was wrong when saved stays
  wrong, silently matching nothing forever. Validate before saving.
- Alerts are account-level. Someone else may depend on one you did not create;
  do not clean up alerts you cannot account for.
- The recipient address receives mail on ONYPHE's schedule, not yours.

## Cross-references

- **onyphe-search** — count the query before saving it.
- **onyphe-honeypot** — validate the indicator before it becomes a standing alert.
- **onyphe-timeline** — reconstructing the past, rather than watching the future.
- **onyphe-hunt** — the final phase, where a validated hunt becomes an alert.
