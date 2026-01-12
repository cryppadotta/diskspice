# 051: Performance Optimization Pass

## Dependencies
- 028 (progressive updates)
- 021 (small items grouping)

## Task
Profile and optimize for smooth 60fps with large file trees.

## Spec Reference
See SPEC.md > Core Principles: "Speed: Instant response, background scanning, never block the UI"

## Implementation Details

Use Instruments to profile:
- Treemap layout calculation
- Canvas drawing
- List scrolling
- State updates

Optimize hot paths. Add caching where beneficial. Consider background threads for heavy computation.

## Files to Create/Modify
- Various files as needed based on profiling

## Acceptance Criteria
- [ ] 60fps maintained with 10,000+ items
- [ ] No UI freezes during scan
- [ ] Smooth scrolling in list
- [ ] Fast treemap layout recalculation
- [ ] Memory usage reasonable
- [ ] App launch time < 2 seconds

## Completion Promise
`<promise>TICKET_051_COMPLETE</promise>`
