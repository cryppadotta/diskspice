# 001: Create Xcode Project

## Dependencies
- None

## Task
Create a new macOS SwiftUI application project in Xcode with proper configuration for DiskSpice.

## Spec Reference
See SPEC.md > Platform section: macOS 14+, SwiftUI, native app.

## Implementation Details

Create a new Xcode project with these settings:
- **Template**: macOS > App
- **Product Name**: DiskSpice
- **Team**: (developer's team)
- **Organization Identifier**: com.diskspice (or appropriate)
- **Interface**: SwiftUI
- **Language**: Swift
- **Minimum Deployment**: macOS 14.0

After creation, update the project settings:

1. In `DiskSpice.entitlements`, add:
```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

2. In `Info.plist`, add the Full Disk Access usage description:
```xml
<key>NSFullDiskAccessUsageDescription</key>
<string>DiskSpice needs Full Disk Access to scan all folders on your disk and show accurate space usage.</string>
```

3. Set the app category in target settings:
   - Application Category: Utilities

## Files to Create/Modify
- `DiskSpice/` - New Xcode project folder
- `DiskSpice.xcodeproj` - Xcode project file
- `DiskSpice/DiskSpiceApp.swift` - App entry point
- `DiskSpice/ContentView.swift` - Main view (placeholder)
- `DiskSpice/Assets.xcassets` - Asset catalog
- `DiskSpice/DiskSpice.entitlements` - Entitlements file

## Acceptance Criteria
- [ ] Xcode project created and opens without errors
- [ ] Project builds successfully (Cmd+B)
- [ ] App runs and shows a window (Cmd+R)
- [ ] Minimum deployment target is macOS 14.0
- [ ] Entitlements file exists with file access permission
- [ ] Info.plist contains Full Disk Access usage description

## Completion Promise
`<promise>TICKET_001_COMPLETE</promise>`
