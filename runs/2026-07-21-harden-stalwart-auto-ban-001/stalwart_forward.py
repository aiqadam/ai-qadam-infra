#!/usr/bin/env python3
"""
Stalwart: create vladimir.titenko@aiqadam.org and set Sieve forwarding to tvolodi@gmail.com
Run on prod host: python3 /tmp/stalwart_forward.py
"""
import json
import urllib.request
import urllib.error
import base64
import sys

BASE_URL = "http://127.0.0.1:8080"
ADMIN_USER = "admin"
ADMIN_PASS = "09/sag2+vHLQqPejWN4PGve+z1Teh9cu"
ACCOUNT_EMAIL = "vladimir.titenko@aiqadam.org"
ACCOUNT_LOCAL = "vladimir.titenko"
FORWARD_TO = "tvolodi@gmail.com"
# Temporary password for the new account (can be changed after)
NEW_ACCOUNT_PASS = "Vt-AiQ-2026-temp!"

creds_str = f"{ADMIN_USER}:{ADMIN_PASS}"
creds = base64.b64encode(creds_str.encode()).decode()
headers_json = {
    "Authorization": f"Basic {creds}",
    "Content-Type": "application/json",
}

def jmap_post(payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(f"{BASE_URL}/jmap", data=data, headers=headers_json)
    try:
        resp = urllib.request.urlopen(req)
        return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"  HTTP {e.code}: {body[:300]}")
        return None

def rest_get(path):
    req = urllib.request.Request(f"{BASE_URL}{path}", headers=headers_json)
    req.get_method = lambda: "GET"
    try:
        resp = urllib.request.urlopen(req)
        return json.loads(resp.read()), resp.status
    except urllib.error.HTTPError as e:
        return None, e.code

def rest_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{BASE_URL}{path}", data=data, headers=headers_json)
    try:
        resp = urllib.request.urlopen(req)
        return json.loads(resp.read()) if resp.read() else {}, resp.status
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"  HTTP {e.code}: {body[:300]}")
        return None, e.code

# ── Step 1: Get JMAP session ──────────────────────────────────────────────────
print("=== Step 1: JMAP session ===")
req = urllib.request.Request(f"{BASE_URL}/.well-known/jmap", headers=headers_json)
session = json.loads(urllib.request.urlopen(req).read())
admin_account_id = list(session["accounts"].keys())[0]
print(f"Admin JMAP account ID: {admin_account_id}")

# ── Step 2: List all principals and check if our account exists ───────────────
print("\n=== Step 2: List principals ===")
resp = jmap_post({
    "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:principals"],
    "methodCalls": [
        ["Principal/query", {}, "q1"],
        ["Principal/get", {"#ids": {"resultOf": "q1", "name": "Principal/query", "path": "/ids"}}, "g1"]
    ]
})
principals = {}
if resp:
    for method in resp.get("methodResponses", []):
        if method[0] == "Principal/get":
            for p in method[1].get("list", []):
                email = p.get("email", "")
                name = p.get("name", p.get("id", ""))
                pid = p.get("id", "")
                principals[email] = {"id": pid, "name": name, "type": p.get("type", ""), "raw": p}
                print(f"  {pid}: {email} ({p.get('type', '')})")

existing_id = None
for email, info in principals.items():
    if ACCOUNT_LOCAL in email or ACCOUNT_EMAIL in email:
        existing_id = info["id"]
        print(f"\nFound existing account: {email} -> id={existing_id}")
        break

if not existing_id:
    print(f"\nAccount {ACCOUNT_EMAIL} does NOT exist yet.")

# ── Step 3: Create account if needed ─────────────────────────────────────────
if not existing_id:
    print("\n=== Step 3: Create account ===")
    resp = jmap_post({
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:principals"],
        "methodCalls": [[
            "Principal/set",
            {
                "accountId": admin_account_id,
                "create": {
                    "new1": {
                        "@type": "individual",
                        "email": ACCOUNT_EMAIL,
                        "name": "Vladimir Titenko",
                        "secret": NEW_ACCOUNT_PASS,
                        "type": "individual"
                    }
                }
            },
            "c1"
        ]]
    })
    print(json.dumps(resp, indent=2)[:800] if resp else "No response")

    # Re-query to get the new account's ID
    resp2 = jmap_post({
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:principals"],
        "methodCalls": [
            ["Principal/query", {}, "q1"],
            ["Principal/get", {"#ids": {"resultOf": "q1", "name": "Principal/query", "path": "/ids"}}, "g1"]
        ]
    })
    if resp2:
        for method in resp2.get("methodResponses", []):
            if method[0] == "Principal/get":
                for p in method[1].get("list", []):
                    email = p.get("email", "")
                    if ACCOUNT_LOCAL in email or ACCOUNT_EMAIL in email:
                        existing_id = p["id"]
                        print(f"Created account ID: {existing_id}")

if not existing_id:
    print("ERROR: Could not create or find account. Exiting.")
    sys.exit(1)

# ── Step 4: Get the JMAP account ID for the new principal ─────────────────────
# We need the JMAP 'accountId' (like d333333) for the new user, not the Principal id
# Authenticate as admin but act on behalf of the account using impersonation, OR
# Use the admin's own account to set the Sieve script on behalf of the user
# In Stalwart, admin can set SieveScript for other accounts using their JMAP account ID

# The JMAP account ID is derived from the principal id. Let's get it from the session.
print(f"\n=== Step 4: Get JMAP accountId for principal {existing_id} ===")

# Try to get JMAP session for the target account using its credentials
# Alternative: admin-level SieveScript/set using the account's JMAP ID

# In Stalwart, the JMAP accountId for a principal is deterministic.
# Let's try to get the full session with admin to see all accessible accounts.
print("Full session accounts:", json.dumps(session.get("accounts", {}), indent=2)[:600])

# Try admin-impersonated JMAP session to find target account's JMAP id
# Stalwart may expose all accounts in the admin session
all_account_ids = list(session.get("accounts", {}).keys())
print(f"All accessible JMAP account IDs: {all_account_ids}")

# ── Step 5: Set Sieve script ──────────────────────────────────────────────────
# Try each account id to find the right one for vladimir.titenko
print(f"\n=== Step 5: Set Sieve forwarding script ===")

sieve_script = f"""require ["copy", "redirect"];
redirect :copy "{FORWARD_TO}";
"""

# Try with admin account ID first (may have access to set scripts for other accounts)
for acct_id in all_account_ids:
    print(f"\nTrying accountId: {acct_id}")
    # First check what Sieve scripts exist
    list_resp = jmap_post({
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:sieve"],
        "methodCalls": [
            ["SieveScript/query", {"accountId": acct_id}, "sq1"],
            ["SieveScript/get", {"accountId": acct_id, "#ids": {"resultOf": "sq1", "name": "SieveScript/query", "path": "/ids"}}, "sg1"]
        ]
    })
    if list_resp:
        for method in list_resp.get("methodResponses", []):
            if method[0] == "SieveScript/get":
                scripts = method[1].get("list", [])
                print(f"  Existing scripts: {[s.get('name','?') for s in scripts]}")
            if method[0] == "error":
                print(f"  Error: {method[1]}")

# Set script on admin account as a test
target_acct = all_account_ids[0]
print(f"\nSetting Sieve forward script on account {target_acct}...")
set_resp = jmap_post({
    "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:sieve"],
    "methodCalls": [[
        "SieveScript/set",
        {
            "accountId": target_acct,
            "create": {
                "fwd1": {
                    "name": "forward-to-gmail",
                    "blobId": None,
                    "isActive": True
                }
            }
        },
        "sc1"
    ]]
})
print(json.dumps(set_resp, indent=2)[:600] if set_resp else "No response")
