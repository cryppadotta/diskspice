# 031: Implement Volume Discovery

## Dependencies
- 003 (core data models - VolumeInfo)
- 027 (scanner UI integration)

## Task
Discover all mounted volumes and display them at the root level as separate rectangles.

## Spec Reference
See SPEC.md > Scanning Engine: "Default scope: All mounted volumes"
See SPEC.md > Window Layout: "At root level, each mounted volume is a separate rectangle"

## Implementation Details

Use FileManager to enumerate mounted volumes. Create VolumeInfo for each. Exclude system/hidden volumes optionally. Show volume name, total/used/free space.

```swift
func discoverVolumes() -> [VolumeInfo] {
    let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsRemovableKey]
    guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else { return [] }
    // ... create VolumeInfo for each
}
```

## Files to Create/Modify
- `DiskSpice/Services/VolumeManager.swift` - New file
- `DiskSpice/App/AppState.swift` - Load volumes on startup

## Acceptance Criteria
- [ ] All mounted volumes discovered on startup
- [ ] Volume name, total, used, free space shown
- [ ] External/removable volumes identified
- [ ] Hidden system volumes excluded
- [ ] Volumes appear as rectangles at root
- [ ] New volumes detected when mounted

## Completion Promise
`<promise>TICKET_031_COMPLETE</promise>`
