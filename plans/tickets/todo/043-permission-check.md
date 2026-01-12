# 043: Create Full Disk Access Permission Check

## Dependencies
- 001 (Xcode project setup)

## Task
Check if app has Full Disk Access permission on startup.

## Spec Reference
See SPEC.md > Platform: "Requires Full Disk Access permission from user"

## Implementation Details

Try to read a protected path (e.g., ~/Library/Mail) to detect FDA status. No direct API exists, so use heuristic check.

```swift
func hasFullDiskAccess() -> Bool {
    let testPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Mail")
    return FileManager.default.isReadableFile(atPath: testPath.path)
}
```

## Files to Create/Modify
- `DiskSpice/Services/PermissionManager.swift` - New file

## Acceptance Criteria
- [ ] Can detect if FDA is granted
- [ ] Check runs on app startup
- [ ] Result stored in AppState
- [ ] Check is fast and reliable
- [ ] Works on different macOS versions

## Completion Promise
`<promise>TICKET_043_COMPLETE</promise>`
