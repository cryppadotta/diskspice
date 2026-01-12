# 056: Cache Sorted Nodes and Treemap Layout to Reduce UI Churn

## Dependencies
- 017 (Canvas treemap renderer)
- 023 (List row polish)

## Task
Reduce UI jank by caching expensive list sorting and treemap layout calculations. Avoid recomputing on every small state change.

## Spec Reference
SPEC.md > Core Principles > Speed, UI Framework (SwiftUI performance).

## Implementation Details
- Add a small cache for sorted nodes keyed by:
  - current path (`navigationState.currentPath`),
  - `sortField`,
  - `sortOrder`,
  - and a lightweight nodes signature (count + total size + lastScanned or a hash of path/size pairs).
- Use cached sorted nodes in:
  - `FileListView` (replace per-render sorting),
  - `ContentView` selection helpers (avoid re-sorting in `selectNextItem` / `selectPreviousItem`).
- Debounce treemap layout recalculation in `TreemapView`:
  - If `nodes` and `viewSize` have not materially changed, reuse existing `rects`.
  - When nodes change rapidly during scanning, coalesce layout recalculations (e.g., 50-100ms delay).
- Ensure cache invalidation when `updateChildren(at:)` is called for the current path.

## Files to Create/Modify
- `DiskSpice/DiskSpice/App/AppState.swift` - add sorted cache and invalidation hooks.
- `DiskSpice/DiskSpice/Views/List/FileListView.swift` - consume cached sorted nodes.
- `DiskSpice/DiskSpice/Views/ContentView.swift` - use cached sorted nodes for keyboard navigation.
- `DiskSpice/DiskSpice/Views/Treemap/TreemapView.swift` - debounce and cache layout results.

## Acceptance Criteria
- [ ] Sorting is not recomputed on every view render for the same path/sort settings.
- [ ] Treemap layout is debounced during rapid scan updates.
- [ ] Keyboard navigation uses the same sorted ordering as the list view without re-sorting.
- [ ] UI remains responsive when scanning directories with thousands of entries.

## Completion Promise
`<promise>TICKET_056_COMPLETE</promise>`
