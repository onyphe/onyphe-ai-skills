# Decision trees

Which branch to take after phase 3's rarity table. Trees feed into each other as
new candidates surface. **Every path ends in something written down** — including
the paths that find nothing.

---

## Tree 1 — The host has a rare attribute (population 1-25)

```
rare attribute found
  |
  +-- population 1
  |     Nothing to pivot TO, but a strong tracking identifier.
  |     -> record it, watch it (onyphe-alert), continue to the next attribute
  |
  +-- population 2-25
        |
        +-- deception gate (phase 4)
              |
              +-- hpish high  -> it is a deception fleet. Record as such and STOP
              |                  this branch. This is a finding, not a dead end.
              |
              +-- hpish low, `other` large
                    |
                    +-- profile the residual by ASN mix and port plausibility
                          |
                          +-- hosting/cloud ASNs, implausible ports, few orgs
                          |     -> emulator fleet the tagging has not reached.
                          |        Record and stop.
                          |
                          +-- consumer/telecom ISPs, standard port, many orgs
                          |     -> real devices. You matched a PRODUCT, not an
                          |        actor. Useful as a filter, not attribution.
                          |
                          +-- mixed, no clear pattern
                                -> pull the cluster, go to Tree 4
```

## Tree 2 — Everything is common (every attribute over ~1000)

The host has no distinctive attribute on its own. Build a *shape* instead: a
combination that is common in each part and rare in combination.

```
no rare attribute
  |
  +-- combine 2-3 ordinary attributes and count the combination
  |     e.g. a port shape plus a device class plus a country
  |
  +-- count the combination
        |
        +-- under 25    -> viable. Go to Tree 1's deception gate.
        +-- 25-200      -> too broad. Add one more constraint and re-count.
        +-- over 200    -> abandon this approach. Go to Tree 6.
```

Service-footprint shapes are the most productive form:

```
category:ctiscan ( ?services.port:8080 ) ( !services.port:80 !services.port:443 )
```

Purpose-built infrastructure tends to have a small, odd footprint. `services.count:1`
on a C2 device class returned 434 documents in a week — a far better starting
point than any single banner.

## Tree 3 — Content-based pivot

When the distinguishing thing is in the response body rather than a header or
certificate.

```
response content looks distinctive
  |
  +-- is the field `keyword` or `text`?
  |     `text` (app.data.text, html.title.text)
  |         -> phrase match only. -regexp: will NEVER match. Use a phrase,
  |            or pivot to app.data.md5.
  |     `keyword` (html.title.raw, http.header.data.raw)
  |         -> -regexp: works. Anchored and case-insensitive: lowercase the
  |            pattern, wrap in .* for a substring.
  |
  +-- STRIP ONYPHE's normalisation tokens first: <srcip> <hostname> <ip>
  |     These are ONYPHE's substitutions, not the target's. A rule built on one
  |     matches everything and means nothing.
  |
  +-- count -> deception gate -> Tree 1
```

An exact response hash (`app.data.md5`) is only usable when the *content* is
implausible on a real host — a protocol violation, an unsubstituted template
placeholder, a game page. A byte-perfect copy of a genuine banner matches the
genuine hosts too.

## Tree 4 — A cluster was found

```
cluster pulled
  |
  +-- deduplicate: opp 'uniq ip.dest | addcount'
  |     documents != hosts. Always quote the host count.
  |
  +-- how many distinct ASNs?
  |     1 ASN        -> suspect a provider fleet. Run the outside-the-ASN test
  |                     on the indicator before claiming an operator.
  |     2 ASNs       -> weak. Needs a second independent indicator.
  |     3+ unrelated -> stronger. One operator across several providers is
  |                     harder to explain as coincidence.
  |
  +-- second independent indicator present on each member?
  |     no  -> membership is unconfirmed. Say so; do not report the raw count
  |            as the cluster size.
  |     yes -> confirmed. Report confirmed/total, e.g. "31/53 confirmed".
  |
  +-- go to Tree 5 for time
```

A 100% confirmation rate on a large candidate set is itself worth a second look:
it usually means both indicators derive from the same underlying thing.

## Tree 5 — Time

```
cluster defined
  |
  +-- count per bucket, same bucket size throughout
  |
  +-- series declines to 0 and stays there
  |     -> probe the retention edge BEFORE reading it as a real decline.
  |        ctiscan returns 0 from about two months back regardless.
  |        Is datascan on this licence?
  |          yes -> cross over, translate the fields, flag the seam
  |          no  -> stop at ctiscan's edge and report the window covered
  |
  +-- a gap of one bucket
  |     -> usually scan cadence, not an outage. Widen the bucket.
  |
  +-- several independent signals change in the same bucket
        -> probable ownership or operator boundary. Do not carry an
           attribution across it without saying you have.
```

## Tree 6 — Nothing linked was found

This is a real outcome and gets the same write-up as any other.

```
no linked infrastructure
  |
  +-- record every query run, with its window and its zero
  +-- record the four exclusions for each zero:
  |     dialect checked / field -exists: / window widened / category authorised
  +-- state the most likely explanation:
  |     - the infrastructure is genuinely singular
  |     - it is not currently listening (ONYPHE sees services, not dormant hosts)
  |     - the distinguishing feature is not in any indexed field
  |     - retention: it existed outside the window available
  +-- name what would extend the search: WHOIS, passive DNS via category:resolver,
      certificate transparency via category:ctl, an external feed
```

"Not currently visible" and "does not exist" are different claims. Only the
first is supportable from a zero.
