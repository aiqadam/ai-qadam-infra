#!/usr/bin/env python3
"""
1. Delete the test Sieve script from admin account (d333333)
2. Upload Sieve forwarding script for vladimir.titenko (accountId=h)
3. Set it active
"""
import json
import urllib.request
import urllib.error
import base64

BASE_URL = "http://127.0.0.1:8080"
ADMIN_CREDS = base64.b64encode(b"admin:09/sag2+vHLQqPejWN4PGve+z1Teh9cu").decode()

TARGET_ACCOUNT_ID = "h"   # vladimir.titenko@aiqadam.org principal id = JMAP account id
ADMIN_ACCOUNT_ID  = "d333333"
FORWARD_TO        = "tvolodi@gmail.com"
SIEVE_SCRIPT_TO_DELETE = "b"   # the test script just created on admin account

def jmap(creds, payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(f"{BASE_URL}/jmap", data=data, headers={
        "Authorization": f"Basic {creds}",
        "Content-Type": "application/json",
    })
    try:
        resp = urllib.request.urlopen(req)
        return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read().decode()[:400]}

# ── 1. Delete the test script from admin account ─────────────────────────────
print("=== Delete test Sieve script from admin account ===")
r = jmap(ADMIN_CREDS, {
    "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:sieve"],
    "methodCalls": [[
        "SieveScript/set",
        {"accountId": ADMIN_ACCOUNT_ID, "destroy": [SIEVE_SCRIPT_TO_DELETE]},
        "d1"
    ]]
})
print(json.dumps(r, indent=2))

# Verify admin has no active scripts
r2 = jmap(ADMIN_CREDS, {
    "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:sieve"],
    "methodCalls": [["SieveScript/query", {"accountId": ADMIN_ACCOUNT_ID}, "q1"]]
})
print("Admin scripts after delete:", r2)

# ── 2. Upload Sieve blob for vladimir.titenko (accountId=h) ──────────────────
print("\n=== Upload Sieve blob for accountId=h ===")
sieve = f'require ["copy", "redirect"];\nredirect :copy "{FORWARD_TO}";\n'.encode()
req = urllib.request.Request(
    f"{BASE_URL}/jmap/upload/{TARGET_ACCOUNT_ID}",
    data=sieve,
    headers={
        "Authorization": f"Basic {ADMIN_CREDS}",
        "Content-Type": "application/sieve",
    }
)
try:
    resp = json.loads(urllib.request.urlopen(req).read())
    print("Upload:", json.dumps(resp, indent=2))
    blob_id = resp.get("blobId")
except urllib.error.HTTPError as e:
    print(f"Upload error {e.code}: {e.read().decode()[:300]}")
    blob_id = None

# ── 3. Set active Sieve script for vladimir.titenko ──────────────────────────
if blob_id:
    print(f"\n=== Set SieveScript on accountId={TARGET_ACCOUNT_ID} ===")
    r = jmap(ADMIN_CREDS, {
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:sieve"],
        "methodCalls": [[
            "SieveScript/set",
            {
                "accountId": TARGET_ACCOUNT_ID,
                "create": {
                    "fwd1": {
                        "name": "forward-to-gmail",
                        "blobId": blob_id,
                        "isActive": True
                    }
                }
            },
            "sc1"
        ]]
    })
    print(json.dumps(r, indent=2))

    # ── 4. Verify ─────────────────────────────────────────────────────────────
    print(f"\n=== Verify: list Sieve scripts for accountId={TARGET_ACCOUNT_ID} ===")
    r = jmap(ADMIN_CREDS, {
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:sieve"],
        "methodCalls": [
            ["SieveScript/query", {"accountId": TARGET_ACCOUNT_ID}, "q1"],
            ["SieveScript/get", {
                "accountId": TARGET_ACCOUNT_ID,
                "#ids": {"resultOf": "q1", "name": "SieveScript/query", "path": "/ids"}
            }, "g1"]
        ]
    })
    print(json.dumps(r, indent=2))
