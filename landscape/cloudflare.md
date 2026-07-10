---
name: cloudflare
last_verified: 2026-07-10
status: stub
---

# Cloudflare

This repo does not currently manage any Cloudflare zones directly.

## Notes

- Neither `ubuntu-16gb-nbg1-1` nor `pro-data-tech-qa` have any Cloudflare DNS records as of 2026-07-10.
- If T-0090a is executed (add nginx + HTTPS for `qadam-test.ai-dala.com`), the DNS record must be created in the `ai-dala.com` zone — which is managed by the `ai-dala-infra` repository. Coordinate with the `ai-dala-infra` repo owner for that step.
- Update this file if this project later acquires its own domain or Cloudflare zone.
