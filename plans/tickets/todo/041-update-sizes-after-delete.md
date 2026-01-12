# 041: Update Sizes After Deletion

## Dependencies
- 039 (move to trash)

## Task
After deleting an item, update parent folder sizes up the tree and animate treemap changes.

## Spec Reference
See SPEC.md > File Operations: "After deletion: update sizes up the tree, animate treemap change"

## Implementation Details

When item deleted: remove from tree, recalculate parent sizes, animate treemap layout transition.

## Files to Create/Modify
- `DiskSpice/App/AppState.swift` - Update tree after delete
- `DiskSpice/Views/Treemap/TreemapContainer.swift` - Animate layout change

## Acceptance Criteria
- [ ] Parent folder size decreases after deletion
- [ ] All ancestors up to root updated
- [ ] Treemap animates to new layout
- [ ] List updates without jarring scroll
- [ ] Summary bar updates

## Completion Promise
`<promise>TICKET_041_COMPLETE</promise>`
