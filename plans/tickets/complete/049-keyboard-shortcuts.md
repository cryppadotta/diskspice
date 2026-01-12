# 049: Add Keyboard Shortcuts

## Dependencies
- 015 (navigation state management)
- 039 (move to trash)
- 036 (search bar)

## Task
Implement all keyboard shortcuts for navigation and actions.

## Spec Reference
See SPEC.md > Navigation: "Keyboard shortcuts: Cmd+[ or Escape to go back, Cmd+Up to go to parent"

## Implementation Details

Shortcuts:
- Cmd+[ : Back
- Cmd+Up : Go to parent
- Escape : Back / Clear search
- Enter : Open selected folder
- Delete/Backspace : Move to Trash
- Cmd+F : Focus search
- Cmd+R : Refresh current folder
- Arrow keys : Navigate list

## Files to Create/Modify
- `DiskSpice/Views/ContentView.swift` - Add key handlers
- `DiskSpice/App/DiskSpiceApp.swift` - Menu bar shortcuts

## Acceptance Criteria
- [ ] All shortcuts work as specified
- [ ] Shortcuts shown in menu bar
- [ ] No conflicts with system shortcuts
- [ ] Work when appropriate views focused
- [ ] Discoverable via menu

## Completion Promise
`<promise>TICKET_049_COMPLETE</promise>`
