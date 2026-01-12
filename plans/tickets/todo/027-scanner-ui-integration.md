# 027: Integrate Scanner with UI State

## Dependencies
- 010 (Swift scanner wrapper)
- 015 (navigation state management)

## Task
Connect the RustScanner to AppState so scan results populate the file tree and update the UI.

## Spec Reference
See SPEC.md > Scanning Engine: "Asynchronous, non-blocking disk traversal"

## Implementation Details

Implement ScannerDelegate in AppState or a coordinator. When scanner emits entries, update the file tree. Sort and update UI on each batch. Use MainActor for UI updates.

```swift
extension AppState: ScannerDelegate {
    func scanner(_ scanner: Scanner, didUpdateNode node: FileNode, at path: URL) {
        Task { @MainActor in
            updateChildren(at: path, adding: node)
        }
    }
    // ... other delegate methods
}
```

## Files to Create/Modify
- `DiskSpice/App/AppState.swift` - Implement ScannerDelegate
- `DiskSpice/Services/ScanCoordinator.swift` - New coordinator class (optional)

## Acceptance Criteria
- [ ] Starting a scan populates the file tree
- [ ] UI updates progressively as entries arrive
- [ ] Entries are sorted by size as they arrive
- [ ] Scanner completion updates isScanning state
- [ ] Errors are captured and displayed
- [ ] Multiple scan sessions don't conflict

## Completion Promise
`<promise>TICKET_027_COMPLETE</promise>`
