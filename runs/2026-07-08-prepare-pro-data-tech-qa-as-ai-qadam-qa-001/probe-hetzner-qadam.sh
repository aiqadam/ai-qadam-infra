#!/bin/bash
echo '--- DOCKER COMPOSE ---'
cat /var/www/ai-qadam/docker-compose.yml
echo '--- ENV KEYS (redacted) ---'
sed -E 's/^([[:space:]]*[A-Z_][A-Z0-9_]+=)(.*)$/\1[REDACTED]/' /var/www/ai-qadam/.env
echo '--- DOCKER PS ---'
docker ps --filter name=ai-qadam --format '{{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'
echo '--- DIR TREE ---'
ls -la /var/www/ai-qadam/
