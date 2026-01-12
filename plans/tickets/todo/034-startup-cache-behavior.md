# 034: Implement Startup Cache Behavior

## Dependencies
- 033 (cache save/load)
- 024 (scanning indicators)

## Task
On startup: immediately show cached data with stale indicators, then auto-start background rescan.

## Spec Reference
See SPEC.md > Caching & Persistence: "Startup behavior" (4 steps)

## Implementation Details

1. Load cache, display immediately with stale status
2. Start background scan
3. Update UI progressively
4. Mark folders as current when rescanned

## Files to Create/Modify
- `DiskSpice/App/DiskSpiceApp.swift` - Startup sequence
- `DiskSpice/App/AppState.swift` - Handle startup flow

## Acceptance Criteria
- [ ] Cached data shows instantly on launch
- [ ] All cached items marked as stale
- [ ] Background scan starts automatically
- [ ] UI updates as fresh data arrives
- [ ] Stale indicators replaced with current

## Completion Promise
`<promise>TICKET_034_COMPLETE</promise>`
