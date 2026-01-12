# 044: Create First-Launch Permission Guide UI

## Dependencies
- 043 (permission check)

## Task
Show friendly onboarding screen explaining FDA need with button to open System Preferences.

## Spec Reference
See SPEC.md > Platform: "First launch: Friendly permission guide explaining FDA need"

## Implementation Details

Full-screen onboarding view with: explanation text, screenshot/illustration, "Open System Preferences" button, "Check Again" button.

```swift
struct PermissionGuideView: View {
    let onOpenSettings: () -> Void
    let onCheckAgain: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
            Text("Full Disk Access Required")
                .font(.title)
            Text("DiskSpice needs permission to scan all folders...")
            Button("Open System Preferences") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            }
        }
    }
}
```

## Files to Create/Modify
- `DiskSpice/Views/Onboarding/PermissionGuideView.swift` - New file
- `DiskSpice/Views/ContentView.swift` - Show guide when needed

## Acceptance Criteria
- [ ] Guide shown on first launch without FDA
- [ ] Clear explanation of why permission needed
- [ ] Button opens correct System Preferences pane
- [ ] Can check if permission granted
- [ ] Dismisses automatically when granted
- [ ] Looks polished and friendly

## Completion Promise
`<promise>TICKET_044_COMPLETE</promise>`
