#!/usr/bin/env python3
import json, urllib.request, urllib.error, base64

BASE = "http://127.0.0.1:8080"
CREDS = base64.b64encode(b"admin:09/sag2+vHLQqPejWN4PGve+z1Teh9cu").decode()
H = {"Authorization": f"Basic {CREDS}", "Content-Type": "application/json"}

def jmap(p):
    try:
        r = urllib.request.urlopen(urllib.request.Request(f"{BASE}/jmap", json.dumps(p).encode(), H))
        return json.loads(r.read())
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read().decode()[:300]}

# Upload Sieve blob for aigerim (accountId=i) and set active
sieve = 'require ["copy", "redirect"];\nredirect :copy "kambetbayeva@gmail.com";\n'.encode()
req = urllib.request.Request(f"{BASE}/jmap/upload/i", sieve, {**H, "Content-Type": "application/sieve"})
upload = json.loads(urllib.request.urlopen(req).read())
blob_id = upload["blobId"]
print(f"Aigerim blob uploaded: {blob_id[:30]}...")

r = jmap({
    "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:sieve"],
    "methodCalls": [["SieveScript/set", {
        "accountId": "i",
        "create": {"fwd1": {"name": "forward-to-gmail", "blobId": blob_id, "isActive": True}}
    }, "sc1"]]
})
res = r["methodResponses"][0][1]
created = res.get("created", {})
not_created = res.get("notCreated", {})
if created:
    print(f"Aigerim Sieve script created: id={created.get('fwd1',{}).get('id')}  OK")
else:
    print(f"FAILED: {not_created}")

# Verify all three accounts
print()
print("=== Verification ===")
ACCOUNTS = [
    ("h", "vladimir.titenko@aiqadam.org",      "tvolodi@gmail.com"),
    ("g", "binali.rustamov@aiqadam.org",        "binali.rustamov@gmail.com"),
    ("i", "aigerim.kambetbayeva@aiqadam.org",   "kambetbayeva@gmail.com"),
]
for account_id, email, dest in ACCOUNTS:
    r = jmap({
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:sieve"],
        "methodCalls": [
            ["SieveScript/query", {"accountId": account_id}, "q1"],
            ["SieveScript/get", {
                "accountId": account_id,
                "#ids": {"resultOf": "q1", "name": "SieveScript/query", "path": "/ids"}
            }, "g1"]
        ]
    })
    scripts = []
    for m in r.get("methodResponses", []):
        if m[0] == "SieveScript/get":
            scripts = m[1].get("list", [])
    active = [s for s in scripts if s.get("isActive")]
    status = "OK" if active else "NO ACTIVE SCRIPT"
    name = active[0]["name"] if active else "none"
    print(f"  {email} -> {dest}: {status} [{name}]")
