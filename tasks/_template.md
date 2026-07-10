---
id: T-NNNN-kebab-slug             # MUST match filename, no .md
title: <one-line title>
kind: observation                 # observation | task
status: observation               # observation | pending | in-progress | blocked | done | failed | wontfix | superseded
priority: P2                      # P0 | P1 | P2 | P3
created: YYYY-MM-DD
updated: YYYY-MM-DD
closed:                           # YYYY-MM-DD, set only when status -> done|wontfix|superseded
outcome:                          # succeeded | failed | abandoned | superseded, set only when closed
created_by: <run_id or "manual">
source_runs: []
executed_by_runs: []
affects: []                       # list of landscape/ paths
workflow: none                    # infrastructure | cicd | discovery-host | discovery-cloudflare | manual | none
blocks: []
blocked_by: []
related: []
estimated_blast_radius: low       # low | medium | high
estimated_reversibility: full     # full | partial | one-way
---

# <Title>

## Why
<one paragraph: the motivation. For observations from discovery runs, quote/summarize the relevant findings and link the source run.>

## What done looks like
- [ ] <acceptance criterion 1>
- [ ] <acceptance criterion 2>

## Result
<empty until closed; then: what actually happened, outcome, links to executing run(s) and commits, any deviations from the plan>

## Notes
<freeform — design considerations, prior discussion, alternatives considered>

## History
- YYYY-MM-DD: created
