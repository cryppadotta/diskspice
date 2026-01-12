# 028: Implement Progressive UI Updates During Scan

## Dependencies
- 027 (scanner UI integration)

## Task
Batch scanner updates to maintain 60fps UI performance. Throttle updates, coalesce changes, animate transitions.

## Spec Reference
See SPEC.md > Scanning Engine: "Sorts results by size as data arrives (progressive)"
See SPEC.md > Visual Design Goals: "Smooth transitions between states"

## Implementation Details

Buffer incoming scan entries and flush to UI at 60fps rate max. Use debouncing/throttling. Animate treemap layout changes smoothly.

## Files to Create/Modify
- `DiskSpice/Services/ScanCoordinator.swift` - Add update batching
- `DiskSpice/Views/Treemap/TreemapView.swift` - Animated layout updates

## Acceptance Criteria
- [ ] UI stays responsive during scan (60fps)
- [ ] Updates appear smoothly, not in jarring batches
- [ ] Treemap animates as items resize/reposition
- [ ] List updates don't cause scroll jumps
- [ ] Large scans don't freeze the UI

## Completion Promise
`<promise>TICKET_028_COMPLETE</promise>`
