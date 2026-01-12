# 002: Set Up Project Folder Structure

## Dependencies
- 001 (Xcode project setup)

## Task
Organize the Xcode project with a clean folder structure for models, views, services, and utilities.

## Spec Reference
General project organization for maintainability.

## Implementation Details

Create the following group/folder structure in Xcode:

```
DiskSpice/
├── App/
│   ├── DiskSpiceApp.swift
│   └── AppState.swift
├── Models/
│   └── (data models will go here)
├── Views/
│   ├── ContentView.swift
│   ├── Components/
│   │   └── (reusable UI components)
│   ├── Treemap/
│   │   └── (treemap-related views)
│   └── List/
│       └── (list view components)
├── Services/
│   └── (scanner, cache, file operations)
├── Utilities/
│   └── (extensions, helpers)
└── Resources/
    ├── Assets.xcassets
    └── (other resources)
```

Create placeholder files:

**App/AppState.swift**:
```swift
import SwiftUI

@Observable
class AppState {
    var isScanning = false
    var currentPath: URL?

    init() {}
}
```

Move existing files to appropriate locations and update imports.

## Files to Create/Modify
- `DiskSpice/App/DiskSpiceApp.swift` - Move from root
- `DiskSpice/App/AppState.swift` - New file
- `DiskSpice/Views/ContentView.swift` - Move from root
- Create empty group folders for Models, Services, Utilities, Components

## Acceptance Criteria
- [ ] All folders/groups created in Xcode project navigator
- [ ] DiskSpiceApp.swift is in App/ folder
- [ ] ContentView.swift is in Views/ folder
- [ ] AppState.swift exists and compiles with @Observable
- [ ] Project still builds and runs after reorganization

## Completion Promise
`<promise>TICKET_002_COMPLETE</promise>`
