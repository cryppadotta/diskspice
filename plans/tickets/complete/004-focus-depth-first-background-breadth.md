# 004: Prioritize Focused DFS and Background BFS

## Dependencies
- 001

## Task
Scan the active folder subtree depth-first to finish what the user is looking at, while keeping background scanning breadth-first.

## Spec Reference
SPEC.md > Scanning Engine; SPEC.md > Navigation

## Implementation Details
- Adjust ScanQueue ordering to prefer deeper paths within the focused subtree.
- Keep non-focused tasks ordered by depth (breadth-first) so high-level folders appear quickly.
- Preserve existing focusRoot behavior.

## Files to Create/Modify
- `DiskSpice/DiskSpice/Services/ScanQueue.swift` - Task ordering changes.

## Acceptance Criteria
- [ ] Focused subtree completes depth-first before unrelated work.
- [ ] Background scanning remains breadth-first.
- [ ] App compiles without errors.

## Completion Promise
`<promise>TICKET_004_COMPLETE</promise>`
