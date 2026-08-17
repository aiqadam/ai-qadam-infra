#!/bin/bash
# Fix mdn_requests: 0 (ask) -> 2 (ignore/never send)
CONFIG=/opt/roundcube/config/config.inc.php
sed -i "s/\$config\['mdn_requests'\] = 0/\$config['mdn_requests'] = 2/" "$CONFIG"
echo "mdn_requests value now:"
grep mdn_requests "$CONFIG"
