# 032: Design Cache Data Structure

## Dependencies
- 003 (core data models)

## Task
Design the persistent cache format for storing scan results between sessions.

## Spec Reference
See SPEC.md > Caching & Persistence: "Results cached to disk between sessions (JSON or SQLite)"

## Implementation Details

Design cache schema storing: path, size, children, file type, scan timestamp, scan status. Use SQLite for efficiency with large trees, or JSON for simplicity. Include cache versioning for migrations.

```swift
struct CacheEntry: Codable {
    let path: String
    let size: Int64
    let isDirectory: Bool
    let fileType: FileType
    let lastScanned: Date
    let childPaths: [String]?
}
```

## Files to Create/Modify
- `DiskSpice/Services/Cache/CacheSchema.swift` - New file

## Acceptance Criteria
- [ ] Cache schema defined
- [ ] All necessary fields included
- [ ] Versioning for future migrations
- [ ] Efficient for trees with millions of nodes
- [ ] Codable for easy serialization

## Completion Promise
`<promise>TICKET_032_COMPLETE</promise>`
