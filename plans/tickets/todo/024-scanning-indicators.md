# 024: Add Scanning/Stale Visual Indicators

## Dependencies
- 014 (basic list view)
- 017 (canvas treemap renderer)

## Task
Implement visual indicators for scan status: stale (reduced opacity), scanning (shimmer), current (full color).

## Spec Reference
See SPEC.md > Caching & Persistence: "Visual status indicators (subtle, non-intrusive)"

## Implementation Details

Add scan status-based styling to both list rows and treemap rectangles:
- Stale: 70% opacity, desaturated
- Scanning: shimmer/pulse animation overlay
- Current: full color
- Error: red badge/indicator

Create reusable `ScanStatusModifier` view modifier and shimmer animation effect.

## Files to Create/Modify
- `DiskSpice/Views/Components/ScanStatusModifier.swift` - New file
- `DiskSpice/Views/List/FileListRow.swift` - Apply status styling
- `DiskSpice/Views/Treemap/TreemapView.swift` - Apply status styling

## Acceptance Criteria
- [ ] Stale items have reduced opacity/saturation
- [ ] Scanning items have subtle shimmer animation
- [ ] Current items display at full color
- [ ] Error items show error badge
- [ ] Animations are smooth 60fps
- [ ] Status changes animate smoothly
- [ ] Visual distinction is clear but not distracting

## Completion Promise
`<promise>TICKET_024_COMPLETE</promise>`
