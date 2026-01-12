# 045: Implement Permission Detection Flow

## Dependencies
- 043 (permission check)
- 044 (permission guide UI)

## Task
Detect when permission is granted (after user enables in System Preferences) and proceed to scan.

## Spec Reference
See SPEC.md > Platform: "Wait/detect when permission granted, then start scan"

## Implementation Details

Poll for permission changes when guide is shown. Use timer or app activation notification. Start scan immediately when granted.

## Files to Create/Modify
- `DiskSpice/Services/PermissionManager.swift` - Add polling/detection
- `DiskSpice/App/DiskSpiceApp.swift` - Handle permission flow

## Acceptance Criteria
- [ ] Detects permission granted within seconds
- [ ] Auto-starts scan when permission granted
- [ ] Guide dismisses automatically
- [ ] No manual "Check Again" needed (but available)
- [ ] Works when app regains focus

## Completion Promise
`<promise>TICKET_045_COMPLETE</promise>`
