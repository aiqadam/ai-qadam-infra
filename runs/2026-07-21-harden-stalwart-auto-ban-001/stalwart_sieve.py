#!/usr/bin/env python3
"""
Test Stalwart Sieve forwarding setup for vladimir.titenko@aiqadam.org -> tvolodi@gmail.com
Run on the prod host: python3 /tmp/stalwart_sieve.py
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
FORWARD_TO = "tvolodi@gmail.com"

creds = base64.b64encode(f"{ADMIN_USER}:{ADMIN_PASS}".encode()).decode()
headers = {
    "Authorization": f"Basic {creds}",
    "Content-Type": "application/json",
}

def jmap_request(payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(f"{BASE_URL}/jmap", data=data, headers=headers)
    try:
        resp = urllib.request.urlopen(req)
        return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.read().decode()}")
        sys.exit(1)

# Step 1: Get JMAP session to find account IDs
print("=== Step 1: JMAP Session ===")
session_req = urllib.request.Request(f"{BASE_URL}/.well-known/jmap", headers=headers)
try:
    session_resp = urllib.request.urlopen(session_req)
    session = json.loads(session_resp.read())
    print("Accounts:", list(session.get("accounts", {}).keys())[:5])
    account_ids = list(session.get("accounts", {}).keys())
except urllib.error.HTTPError as e:
    print(f"Session error {e.code}: {e.read().decode()[:200]}")
    # Try direct JMAP echo
    session = {}
    account_ids = []

# Step 2: Try to find/query accounts using x:Principal
print("\n=== Step 2: Query accounts ===")
resp = jmap_request({
    "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:principals"],
    "methodCalls": [["Principal/query", {}, "q1"]]
})
print(json.dumps(resp, indent=2)[:500])

# Step 3: Try x:Account/query (Stalwart extension)
print("\n=== Step 3: x:Account/query ===")
resp = jmap_request({
    "using": ["urn:ietf:params:jmap:core", "x:stalwart:mail:account"],
    "methodCalls": [["x:Account/query", {}, "q1"]]
})
print(json.dumps(resp, indent=2)[:500])
