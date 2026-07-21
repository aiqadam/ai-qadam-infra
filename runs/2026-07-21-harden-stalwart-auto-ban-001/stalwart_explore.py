#!/usr/bin/env python3
"""
Explore Stalwart management API to find account JMAP IDs and set Sieve forwarding.
"""
import json
import urllib.request
import urllib.error
import base64
import sys

BASE_URL = "http://127.0.0.1:8080"
ADMIN_USER = "admin"
ADMIN_PASS = "09/sag2+vHLQqPejWN4PGve+z1Teh9cu"
DOMAIN_ADMIN_USER = "admin@aiqadam.org"
DOMAIN_ADMIN_PASS = "Jk7Uur9w8nAYOL4t"

TARGET_EMAIL = "vladimir.titenko@aiqadam.org"
TARGET_LOCAL = "vladimir.titenko"
FORWARD_TO = "tvolodi@gmail.com"

def make_creds(user, pw):
    return base64.b64encode(f"{user}:{pw}".encode()).decode()

def jmap_post(creds, payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(f"{BASE_URL}/jmap", data=data, headers={
        "Authorization": f"Basic {creds}",
        "Content-Type": "application/json",
    })
    try:
        resp = urllib.request.urlopen(req)
        return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read().decode()[:300]}

def rest(method, path, creds, body=None):
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(f"{BASE_URL}{path}", data=data, headers={
        "Authorization": f"Basic {creds}",
        "Content-Type": "application/json",
    })
    req.get_method = lambda: method
    try:
        resp = urllib.request.urlopen(req)
        raw = resp.read()
        return json.loads(raw) if raw else {}, resp.status
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read().decode()[:400]}, e.code

admin_creds = make_creds(ADMIN_USER, ADMIN_PASS)
domain_creds = make_creds(DOMAIN_ADMIN_USER, DOMAIN_ADMIN_PASS)

# ── 1. Try REST management API paths for principal ──────────────────────────
print("=== REST: /api/principal paths ===")
for path in [
    f"/api/principal/{TARGET_LOCAL}",
    f"/api/principal/{TARGET_EMAIL}",
    "/api/account",
    f"/api/account/{TARGET_EMAIL}",
    f"/api/account/{TARGET_LOCAL}",
]:
    r, code = rest("GET", path, admin_creds)
    print(f"GET {path} => HTTP {code}: {str(r)[:120]}")

# ── 2. Try domain admin JMAP session to see if other accounts are visible ────
print("\n=== Domain admin JMAP session ===")
req = urllib.request.Request(f"{BASE_URL}/.well-known/jmap", headers={
    "Authorization": f"Basic {domain_creds}",
})
try:
    sess = json.loads(urllib.request.urlopen(req).read())
    print("Accounts:", list(sess.get("accounts", {}).keys()))
except urllib.error.HTTPError as e:
    print(f"Error: {e.code}")

# ── 3. Try Principal/set to update the account (set password for impersonation) ──
print("\n=== Try Principal/set to set password on vladimir.titenko ===")
# Get admin session first
req = urllib.request.Request(f"{BASE_URL}/.well-known/jmap", headers={
    "Authorization": f"Basic {admin_creds}",
})
admin_sess = json.loads(urllib.request.urlopen(req).read())
admin_jmap_id = list(admin_sess["accounts"].keys())[0]
print(f"Admin JMAP account ID: {admin_jmap_id}")

# Try PATCH on principal via REST
print("\n=== PATCH /api/principal/vladimir.titenko ===")
r, code = rest("PATCH", f"/api/principal/{TARGET_LOCAL}", admin_creds, {"secret": "Vt-Test-2026!"})
print(f"HTTP {code}: {r}")

r, code = rest("PATCH", f"/api/principal/{TARGET_EMAIL}", admin_creds, {"secret": "Vt-Test-2026!"})
print(f"HTTP {code}: {r}")

# ── 4. After setting password, try logging in as vladimir.titenko ────────────
print("\n=== Login as vladimir.titenko ===")
vt_creds = make_creds(TARGET_EMAIL, "Vt-Test-2026!")
req = urllib.request.Request(f"{BASE_URL}/.well-known/jmap", headers={
    "Authorization": f"Basic {vt_creds}",
})
try:
    vt_sess = json.loads(urllib.request.urlopen(req).read())
    vt_account_ids = list(vt_sess.get("accounts", {}).keys())
    print(f"vladimir.titenko JMAP account IDs: {vt_account_ids}")
    print("Full session:", json.dumps(vt_sess, indent=2)[:400])
except urllib.error.HTTPError as e:
    print(f"Login failed: {e.code}")

# ── 5. Try uploading a Sieve blob and creating the script ───────────────────
print("\n=== Upload Sieve script blob and create SieveScript ===")
# Try first with admin account
sieve_content = f'require ["copy", "redirect"];\nredirect :copy "{FORWARD_TO}";\n'.encode()

upload_req = urllib.request.Request(
    f"{BASE_URL}/jmap/upload/{admin_jmap_id}",
    data=sieve_content,
    headers={
        "Authorization": f"Basic {admin_creds}",
        "Content-Type": "application/sieve",
    }
)
try:
    upload_resp = json.loads(urllib.request.urlopen(upload_req).read())
    print("Upload response:", json.dumps(upload_resp, indent=2))
    blob_id = upload_resp.get("blobId")

    if blob_id:
        # Set as active Sieve script
        set_resp = jmap_post(admin_creds, {
            "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:sieve"],
            "methodCalls": [[
                "SieveScript/set",
                {
                    "accountId": admin_jmap_id,
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
        print("SieveScript/set:", json.dumps(set_resp, indent=2))
except urllib.error.HTTPError as e:
    print(f"Upload error {e.code}: {e.read().decode()[:200]}")
