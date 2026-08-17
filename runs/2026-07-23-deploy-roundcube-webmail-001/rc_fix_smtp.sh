#!/bin/bash
# Append config overrides to Roundcube config (idempotent)
HOST_CONFIG=/opt/roundcube/config/config.inc.php

if grep -q "mdn_requests" "$HOST_CONFIG"; then
  echo "mdn_requests already set."
else
  echo "    \$config['mdn_requests'] = 0; // disable MDN read receipts (sendmdn sender empty on Stalwart)" >> "$HOST_CONFIG"
  echo "Patched mdn_requests."
fi

tail -4 "$HOST_CONFIG"

echo "--- Last 5 lines of config ---"
tail -5 "$CONFIG"
