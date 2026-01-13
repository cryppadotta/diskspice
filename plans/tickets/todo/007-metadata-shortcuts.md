# 007: Add Metadata Shortcuts for Fast Estimates

## Dependencies
- 001

## Task
Use file metadata to provide fast size estimates without full traversal, then refine later.

## Spec Reference
SPEC.md > Scanning Engine

## Implementation Details
- Prefer allocated size/metadata-derived size for quick estimates.
- Avoid blocking operations during the initial pass.
- Ensure estimates are marked as partial until full scan completion.

## Files to Create/Modify
- `DiskSpice/DiskSpice/Services/SwiftScanner.swift` - Use metadata-based estimates.
- `DiskSpice/DiskSpice/App/AppState.swift` - Merge partial sizes with final sizes.

## Acceptance Criteria
- [ ] Directory entries show metadata-based estimates quickly.
- [ ] Full scans replace estimates when done.
- [ ] App compiles without errors.

## Completion Promise
`<promise>TICKET_007_COMPLETE</promise>`
