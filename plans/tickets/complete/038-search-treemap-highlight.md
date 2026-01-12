# 038: Implement Search Highlighting in Treemap

## Dependencies
- 036 (search bar)
- 017 (canvas treemap renderer)

## Task
Highlight matching items in treemap with outline/glow when searching.

## Spec Reference
See SPEC.md > Search: "Matches highlighted in treemap (outline/glow)"

## Implementation Details

Pass search matches to treemap. Draw glow/outline around matching rectangles. Dim non-matching items.

## Files to Create/Modify
- `DiskSpice/Views/Treemap/TreemapView.swift` - Add search highlight

## Acceptance Criteria
- [ ] Matching items have visible highlight
- [ ] Non-matching items slightly dimmed
- [ ] Highlight animates in/out smoothly
- [ ] Multiple matches all highlighted
- [ ] Clear search removes highlights

## Completion Promise
`<promise>TICKET_038_COMPLETE</promise>`
