# 047: Implement Stale node_modules Finder

## Dependencies
- 046 (utilities panel shell)
- 010 (Swift scanner wrapper)

## Task
Find node_modules folders that haven't been accessed recently.

## Spec Reference
See SPEC.md > Smart Utilities Panel: "Stale node_modules finder"

## Implementation Details

Scan for directories named "node_modules". Check last access time. Show list sorted by size with project name, size, last accessed. Allow configurable age threshold (default 30 days).

```swift
struct StaleNodeModules {
    let path: URL
    let projectName: String // parent folder name
    let size: Int64
    let lastAccessed: Date
}

func findStaleNodeModules(olderThan days: Int) async -> [StaleNodeModules]
```

## Files to Create/Modify
- `DiskSpice/Views/Utilities/NodeModulesFinder.swift` - New file
- `DiskSpice/Services/UtilityScanner.swift` - Scanning logic

## Acceptance Criteria
- [ ] Finds all node_modules directories
- [ ] Shows project name (parent folder)
- [ ] Shows size and last accessed date
- [ ] Configurable age threshold
- [ ] Sorted by size (largest first)
- [ ] Progress indicator during scan

## Completion Promise
`<promise>TICKET_047_COMPLETE</promise>`
