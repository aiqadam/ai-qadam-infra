---
name: mail-provisioning-protocol
version: 1
---

# Mail provisioning protocol

How `@aiqadam.org` mailboxes get requested and created, since T-0117 stood up a self-hosted mail server (Stalwart, on `pro-data-tech-prod`) with no self-service signup — see [`landscape/hosts/pro-data-tech-prod.md`](../landscape/hosts/pro-data-tech-prod.md) for the technical deployment detail.

## Who can get a mailbox

Open to anyone in the ai-qadam community — self-service request, admin-approved creation (not fully automatic).

## How to request one

Email **`postmaster@aiqadam.org`** with the address you want (e.g. `firstname@aiqadam.org`) and what it's for. `postmaster@` is a real mailbox (created 2026-07-20) checked by the admin group — there is no web form or ticketing system for this yet.

## Who creates them

Any trusted admin with the Stalwart admin panel login (`https://mail.aiqadam.org/`, `admin@aiqadam.org` — see `credentials.md`, not this repo).

## How to create a mailbox (admin steps)

Via the web admin panel (no CLI needed for routine use):

1. Log in at `https://mail.aiqadam.org/` with an admin account.
2. Navigate to account/mailbox management, create a new account under the `aiqadam.org` domain with the requested local part.
3. Set an initial password (or let Stalwart generate one) and relay it to the requester through a secure channel — never paste a real mailbox password into a shared doc, chat log, or this repo.
4. Confirm the mailbox works: the requester should be able to log in via webmail (if configured) or a mail client using IMAP (`mail.aiqadam.org:993`) / SMTP submission (`mail.aiqadam.org:587` or `:465`).

If the admin panel is unavailable, the equivalent can be done via `stalwart-cli`/raw JMAP `x:Account/set` calls — see [`landscape/hosts/pro-data-tech-prod.md`](../landscape/hosts/pro-data-tech-prod.md)'s "Mailbox provisioning" and "Stalwart CLI gotchas" sections for the exact object shape (`@type: "User"`, numeric-string-keyed `credentials` map — this is not obvious from Stalwart's own docs and was discovered the hard way during T-0117).

## Automated provisioning (platform-integrated)

Agreed design (2026-07-23, [T-0123](../tasks/T-0123-automated-mailbox-provisioning-on-user-registration.md)): mailbox creation is integrated into the platform's user registration flow rather than being a separate manual request.

### Flow

1. User fills the registration form on aiqadam.org (chapter/tenant, personal email, username, etc.)
2. The NestJS `apps/api` creates the platform user record.
3. After the user record is committed, `MailboxService.provision(username)` is called:
   - Creates `<username>@aiqadam.org` via Stalwart JMAP `x:Account/set` (loopback `http://127.0.0.1:8080`, admin credentials from env)
   - Failure is **logged but does not roll back** the platform registration (no transactionality by design)
4. A "set your password" link is emailed to the user's personal (registration) address via Stalwart SMTP submission (`mail.aiqadam.org:587`, sender `postmaster@aiqadam.org`). A raw password is never emailed.

### Mailbox naming

`<platform_username>@aiqadam.org` — the platform enforces global username uniqueness, so collisions are prevented for new registrations. Pre-existing manually-provisioned accounts (e.g. `vladimir.titenko`, `binali.rustamov`) may conflict if the same string is chosen as a username; `MailboxService` detects the JMAP conflict error and logs a warning without crashing registration.

### Forwarding (on request)

Forwarding is **not** set up automatically at registration. It is a separate, explicitly-triggered action. When requested, `MailboxService.enableForwarding(username, forwardTo)` uploads a Sieve script for the user using a single fixed template — no new script design per user:

```sieve
require ["copy", "redirect"];
redirect :copy "<FORWARD_TO>";
```

Only the destination address is substituted. Stalwart requires a per-user blob (shared scripts across accounts are not supported by the JMAP API), but the template itself is a single code-level constant.

### Required secrets / env vars

| Secret name | Used for |
|---|---|
| `aiqadam-prod-stalwart-admin-password` | JMAP admin auth (`x:Account/set` calls) |
| `aiqadam-prod-stalwart-postmaster-password` | SMTP submission for outbound registration email |

Both injected into the api container's env file. See `landscape/secrets-inventory.md`.

### Manual flow still applies

The manual request → admin-creates flow described below remains valid for edge cases (e.g. admin override, accounts for non-registering team members, pre-platform accounts). It does not replace the automated flow — both coexist.

---

## What this protocol does not cover (manual-only scope)

- **Deletion/offboarding** — not yet defined. Until it is, deleting a mailbox is an ad hoc admin action; consider revisiting once the community has enough mailboxes for this to matter.

## Notes

- This protocol governs the *process*; the underlying infrastructure is documented in `landscape/`, not here — this file will go stale if the mail server's admin URL, host, or object model changes without a corresponding update.
- Related: [T-0117](../tasks/T-0117-install-mail-server-aiqadam.md) (original deployment), [T-0121](../tasks/T-0121-harden-stalwart-auto-ban-against-bridge-ip.md) (a 2026-07-20 outage affecting this same admin panel — worth being aware the panel can go down if scanning traffic trips Stalwart's auto-ban).

## How to connect

ssh -i "~/.ssh/[private key]" -o IdentitiesOnly=yes -L 9080:127.0.0.1:8080 [username]@95.46.211.224
e.g. 
ssh -i ~/.ssh/<their-key> -o IdentitiesOnly=yes -L 9080:127.0.0.1:8080 viktor_d|binali_r@95.46.211.224

http://localhost:9080

## Preregistered mailboxes (all provisioned):
| Email | Forward to | Principal id | Sieve script | Done |
|---|---|---|---|---|
| vladimir.titenko@aiqadam.org | tvolodi@gmail.com | h | forward-to-gmail (id=b, :copy) | 2026-07-21 |
| binali.rustamov@aiqadam.org | binali.rustamov@gmail.com | g | forward-to-gmail (id=b, :copy) | 2026-07-23 |
| aigerim.kambetbayeva@aiqadam.org | kambetbayeva@gmail.com | i | forward-to-gmail (id=b, :copy) | 2026-07-23 |

Note: `aigerim.kambetbayeva` was created via `x:Account/set` (JMAP, domainId=b) since `Principal/set` create is read-only in Stalwart v0.16. All others pre-existed.

## How to set Sieve forwarding via JMAP API (admin, from prod host)

Pattern discovered 2026-07-21. All calls from inside the Docker network (127.0.0.1:8080) or via SSH tunnel.

Admin credentials: recovery admin (`admin` / see credentials.md `stalwart-mail-admin-password`).

Key JMAP IDs:
- Recovery admin JMAP accountId: `d333333`
- Principals (accountId = principal id for regular users):
  - b = admin@aiqadam.org
  - e = test@aiqadam.org
  - f = postmaster@aiqadam.org
  - g = binali.rustamov@aiqadam.org
  - h = vladimir.titenko@aiqadam.org

Steps (Python, run on prod host or via SSH):

```python
import json, urllib.request, base64

BASE = "http://127.0.0.1:8080"
CREDS = base64.b64encode(b"admin:<stalwart-mail-admin-password>").decode()
H = {"Authorization": f"Basic {CREDS}", "Content-Type": "application/json"}

ACCOUNT_ID = "h"          # target user's principal id
FORWARD_TO = "dest@example.com"

def jmap(p):
    r = urllib.request.urlopen(urllib.request.Request(f"{BASE}/jmap", json.dumps(p).encode(), H))
    return json.loads(r.read())

# 1. Upload Sieve script as a blob
sieve = f'require ["copy", "redirect"];\nredirect :copy "{FORWARD_TO}";\n'.encode()
upload = urllib.request.urlopen(urllib.request.Request(
    f"{BASE}/jmap/upload/{ACCOUNT_ID}", sieve,
    {**H, "Content-Type": "application/sieve"}
))
blob_id = json.loads(upload.read())["blobId"]

# 2. Create active SieveScript referencing the blob
r = jmap({"using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:sieve"],
          "methodCalls": [["SieveScript/set", {"accountId": ACCOUNT_ID,
              "create": {"fwd1": {"name": "forward-to-gmail", "blobId": blob_id, "isActive": True}}
          }, "sc1"]]})
print(r["methodResponses"][0][1].get("created"))  # expect {"fwd1": {"id": "...", "blobId": "..."}}
```

To delete/disable forwarding:
```python
# First deactivate, then destroy
jmap({"using": [...sieve caps...], "methodCalls": [["SieveScript/set", {"accountId": ACCOUNT_ID, "update": {"<script-id>": {"isActive": False}}}, "u1"]]})
jmap({"using": [...sieve caps...], "methodCalls": [["SieveScript/set", {"accountId": ACCOUNT_ID, "destroy": ["<script-id>"]}, "d1"]]})
```

Note: `/api/principal` REST endpoint returns 404 in Stalwart v0.16 — use JMAP `Principal/query` + `Principal/get` (with `urn:ietf:params:jmap:principals`) instead.

