# 050: Implement Dark/Light Mode Support

## Dependencies
- 017 (canvas treemap renderer)
- 018 (file type colors)

## Task
Ensure app follows system appearance and looks great in both modes.

## Spec Reference
See SPEC.md > UI Framework: "Appearance: Follow system (auto light/dark mode)"

## Implementation Details

Use semantic colors everywhere. Test all views in both modes. Ensure file type colors work in both. Use @Environment(\.colorScheme).

## Files to Create/Modify
- All view files - Verify semantic colors used
- `DiskSpice/Views/Treemap/FileTypeColors.swift` - Mode-aware colors

## Acceptance Criteria
- [ ] Automatically follows system appearance
- [ ] All UI elements look correct in light mode
- [ ] All UI elements look correct in dark mode
- [ ] Smooth transition when mode changes
- [ ] File type colors readable in both modes
- [ ] No hardcoded colors

## Completion Promise
`<promise>TICKET_050_COMPLETE</promise>`
