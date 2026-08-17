#!/usr/bin/env python3
"""
Set Sieve forwarding for:
  - binali.rustamov@aiqadam.org  (principal g)  -> binali.rustamov@gmail.com
  - aigerim.kambetbayeva@aiqadam.org             -> kambetbayeva@gmail.com  (create if missing)
"""
import json, urllib.request, urllib.error, base64, sys

BASE = "http://127.0.0.1:8080"
CREDS = base64.b64encode(b"admin:09/sag2+vHLQqPejWN4PGve+z1Teh9cu").decode()
H = {"Authorization": f"Basic {CREDS}", "Content-Type": "application/json"}

ACCOUNTS = [
    {"local": "binali.rustamov",       "email": "binali.rustamov@aiqadam.org",       "forward": "binali.rustamov@gmail.com",   "name": "Binali Rustamov"},
    {"local": "aigerim.kambetbayeva",  "email": "aigerim.kambetbayeva@aiqadam.org",  "forward": "kambetbayeva@gmail.com",      "name": "Aigerim Kambetbayeva"},
]
NEW_PASS = "AiQ-temp-2026!"

def jmap(p):
    data = json.dumps(p).encode()
    req = urllib.request.Request(f"{BASE}/jmap", data, H)
    try:
        return json.loads(urllib.request.urlopen(req).read())
    except urllib.error.HTTPError as e:
        print(f"  JMAP error {e.code}: {e.read().decode()[:300]}")
        return None

def upload_sieve(account_id, forward_to):
    script = f'require ["copy", "redirect"];\nredirect :copy "{forward_to}";\n'.encode()
    req = urllib.request.Request(
        f"{BASE}/jmap/upload/{account_id}", script,
        {**H, "Content-Type": "application/sieve"}
    )
    try:
        return json.loads(urllib.request.urlopen(req).read())["blobId"]
    except urllib.error.HTTPError as e:
        print(f"  Upload error {e.code}: {e.read().decode()[:200]}")
        return None

# ── Get JMAP session ──────────────────────────────────────────────────────────
sess = json.loads(urllib.request.urlopen(
    urllib.request.Request(f"{BASE}/.well-known/jmap", headers=H)
).read())
admin_jmap_id = list(sess["accounts"].keys())[0]

# ── Get existing principals ───────────────────────────────────────────────────
r = jmap({
    "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:principals"],
    "methodCalls": [
        ["Principal/query", {}, "q1"],
        ["Principal/get", {"#ids": {"resultOf": "q1", "name": "Principal/query", "path": "/ids"}}, "g1"]
    ]
})
principals = {}
for method in r.get("methodResponses", []):
    if method[0] == "Principal/get":
        for p in method[1].get("list", []):
            principals[p.get("email", "")] = p["id"]

print("Existing principals:", {k: v for k, v in principals.items()})

# ── Process each account ──────────────────────────────────────────────────────
for acct in ACCOUNTS:
    print(f"\n{'='*60}")
    print(f"Account: {acct['email']} -> {acct['forward']}")

    # Find or create
    account_id = None
    for email, pid in principals.items():
        if acct["local"] in email:
            account_id = pid
            print(f"  Found existing: principal id={account_id}")
            break

    if not account_id:
        print(f"  Creating account...")
        cr = jmap({
            "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:principals"],
            "methodCalls": [["Principal/set", {
                "accountId": admin_jmap_id,
                "create": {"new1": {
                    "type": "individual",
                    "name": acct["name"],
                    "email": acct["email"],
                    "secret": NEW_PASS,
                }}
            }, "c1"]]
        })
        result = cr["methodResponses"][0][1] if cr else {}
        created = result.get("created", {}).get("new1", {})
        not_created = result.get("notCreated", {}).get("new1", {})
        if created:
            # Re-query to get ID
            r2 = jmap({
                "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:principals"],
                "methodCalls": [
                    ["Principal/query", {}, "q1"],
                    ["Principal/get", {"#ids": {"resultOf": "q1", "name": "Principal/query", "path": "/ids"}}, "g1"]
                ]
            })
            for method in r2.get("methodResponses", []):
                if method[0] == "Principal/get":
                    for p in method[1].get("list", []):
                        if acct["local"] in p.get("email", ""):
                            account_id = p["id"]
                            print(f"  Created: principal id={account_id}")
        elif not_created:
            print(f"  Create FAILED: {not_created}")
            continue

    if not account_id:
        print("  ERROR: could not determine account id, skipping.")
        continue

    # Check existing Sieve scripts
    existing = jmap({
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:sieve"],
        "methodCalls": [
            ["SieveScript/query", {"accountId": account_id}, "q1"],
            ["SieveScript/get", {"accountId": account_id, "#ids": {"resultOf": "q1", "name": "SieveScript/query", "path": "/ids"}}, "g1"]
        ]
    })
    scripts = []
    for method in (existing or {}).get("methodResponses", []):
        if method[0] == "SieveScript/get":
            scripts = method[1].get("list", [])
    print(f"  Existing Sieve scripts: {[s.get('name') for s in scripts]}")

    # Upload and set
    print(f"  Uploading Sieve blob for accountId={account_id}...")
    blob_id = upload_sieve(account_id, acct["forward"])
    if not blob_id:
        continue

    sr = jmap({
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:sieve"],
        "methodCalls": [["SieveScript/set", {
            "accountId": account_id,
            "create": {"fwd1": {"name": "forward-to-gmail", "blobId": blob_id, "isActive": True}}
        }, "sc1"]]
    })
    result = sr["methodResponses"][0][1] if sr else {}
    created = result.get("created", {})
    not_created = result.get("notCreated", {})
    if created:
        script_id = created.get("fwd1", {}).get("id")
        print(f"  Sieve script created: id={script_id}, active=True  OK")
    else:
        print(f"  Sieve script FAILED: {not_created}")

    # Verify
    verify = jmap({
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:sieve"],
        "methodCalls": [
            ["SieveScript/query", {"accountId": account_id}, "q1"],
            ["SieveScript/get", {"accountId": account_id, "#ids": {"resultOf": "q1", "name": "SieveScript/query", "path": "/ids"}}, "g1"]
        ]
    })
    for method in (verify or {}).get("methodResponses", []):
        if method[0] == "SieveScript/get":
            for s in method[1].get("list", []):
                print(f"  Verified: name={s['name']}, isActive={s['isActive']}, id={s['id']}")

print("\nDone.")
