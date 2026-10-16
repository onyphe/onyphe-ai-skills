# OQL cookbook

Every query below was run with `onyphe -count -search` on **2026-09-25** against
a Griffin View licence; the count is what it returned. None of them is a
starting point invented from the schema — they all match real data.

Counts drift. A query that returns nothing later is a prompt to re-measure, not
evidence that the population vanished.

| What it finds | Count | Query |
|---|---:|---|
| Cobalt Strike team servers, by certificate issuer | 6 | `category:ctiscan cert.issuer.cn:"Major Cobalt Strike" -dayago:1` |
| Cobalt Strike, by certificate subject org | 61 | `category:ctiscan cert.subject.o:"cobaltstrike" -weekago:1` |
| Everything ONYPHE classes as C2 | 22391 | `category:ctiscan app.device:c2 -weekago:1` |
| C2 not on 80 or 443 | 21283 | `category:ctiscan app.device:c2 !tcp.dest:443 !tcp.dest:80 -weekago:1` |
| C2 with a single open port | 434 | `category:ctiscan app.device:c2 services.count:1 -weekago:1` |
| Expired certificates, scoped to RDP | 319 | `category:ctiscan app.protocol:rdp cert.validity.expired:true -dayago:1` |
| Machine-generated RDP certificate CNs | 65545 | `category:ctiscan app.protocol:rdp -regexp:cert.subject.dn,"cn=[a-z0-9]{15}" -dayago:1` |
| Open directories, URL level | 818937 | `category:ctiurl html.title.text:"index of" -weekago:1` |
| MeshCentral by page title | 9293 | `category:ctiscan html.title.text:MeshCentral -weekago:1` |
| Ivanti components | 4276875 | `category:ctiscan component.text:ivanti -weekago:1` |
| SCADA devices | 166601 | `category:ctiscan app.device:scada -weekago:1` |
| Medical devices | 14923 | `category:ctiscan app.device:medical -weekago:1` |
| Exposed databases | 212014 | `category:ctiscan app.device:database tag:open -weekago:1` |
| Port shape: 8080 open, neither 80 nor 443 | 4224943 | `category:ctiscan ( ?services.port:8080 ) ( !services.port:80 !services.port:443 ) -dayago:1` |
| Compromised hosts | 6275 | `category:ctiscan tag:compromised -dayago:1` |
| Tagged honeypots | 25769626 | `category:ctiscan tag:honeypot -dayago:1` |
| One host, full ctiscan view | 27 | `category:ctiscan ip.dest:8.8.8.8 -weekago:1` |
| Typosquat lookalikes in passive DNS | 1219 | `category:resolver -wildcard:domain,g??gle.com !domain:google.com -weekago:1` |
| Honeypot self-identification in a page title | 65 | `category:ctiscan -regexp:html.title.raw,".*honeypot.*" -dayago:1` |

## Reading these counts

The spread is the lesson. `cert.issuer.cn:"Major Cobalt Strike"` returns **6**
documents a day; `-exists:hhhash.fingerprint.md5` returns **171 962 592**. Both
are "a pivot". Only one of them narrows anything.

Before treating a count as a finding:

- **Under ~5** — candidate operator artefact. Confirm with a second, independent
  attribute before claiming a cluster.
- **5–25** — worth pivoting on.
- **Over ~25** — shared infrastructure, a product default, or a template. Useful
  as a filter, not as attribution.
- **0** — inconclusive until you have excluded the wrong field dialect, an
  unpopulated field, too narrow a window, and an unauthorised category. See
  `onyphe-search`.

And in every case, run the candidate through `onyphe-hpcheck.sh` before calling
it tradecraft. Roughly one ctiscan document in nine carries `tag:honeypot`
(25 769 626 of 229 980 327 on 2026-09-25), so a population that looks like an
actor is quite often a deception fleet.

## Device classes that exist

`app.device` values seen in a 2000-document sample, most common first:

```
Web Server              Remote Access Control   Undefined      Router
Database                Email Server            Proxy          IMAP Server
POP3 Server             Load Balancer           Webmail        VPN Server
Firewall                FTP Server              RTSP Server    Camera
Container               DNS Server              Management Console
SMB/CIFS Server         RPC Server              WinRM Server   Printer
NAS                     FGFM Server
```

Plus `C2`, `SCADA` and `Medical`, which are rarer but present (22 391, 166 601
and 14 923 respectively over a week). Matching is case-insensitive, and values
with a space need quoting: `app.device:"vpn server"`.

`app.device:infostealer` returns **0** — that class does not exist in ctiscan,
whatever a datascan-era dork may say.
