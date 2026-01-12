# 033: Implement Cache Save/Load

## Dependencies
- 032 (cache data structure)

## Task
Implement saving scan results to disk and loading them on startup.

## Spec Reference
See SPEC.md > Caching & Persistence

## Implementation Details

Save cache to ~/Library/Application Support/DiskSpice/cache.json (or SQLite). Load on app startup. Handle missing/corrupt cache gracefully.

## Files to Create/Modify
- `DiskSpice/Services/Cache/CacheManager.swift` - New file

## Acceptance Criteria
- [ ] Cache saves after scan completes
- [ ] Cache loads on app startup
- [ ] Corrupt cache handled gracefully
- [ ] Cache location is appropriate for macOS
- [ ] Large caches save/load efficiently

## Completion Promise
`<promise>TICKET_033_COMPLETE</promise>`
