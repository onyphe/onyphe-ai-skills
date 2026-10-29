---
type: llm
focus: whether co-tenant vhosts are distinguished from the target actor's infrastructure
criteria: |
  1.0 - The answer treats the shared IP as weak attribution: it separates the
        vhosts on the address from the address itself, and says plainly that a
        co-tenant's vhost is not the actor's infrastructure. Comparing vhost
        fan-out against distinct hosts, or requiring a second indicator the
        hoster does not supply (tracker ID, body hash) rather than a shared
        wildcard certificate, are strong signals.
  0.5 - The answer gathers the vhosts but does not address whether they belong
        to the same operator, leaving the attribution ambiguous.
  0.0 - The answer attributes every vhost on the address to the target actor, or
        reports the IP's co-tenants as the actor's estate.
---

On shared hosting `ip.dest` attributes the host to the hoster, not the operator.
Reporting the whole tenancy as one cluster is the characteristic failure.
