# 054: Move ScanQueue and SwiftScanner Work Off Main Thread

## Dependencies
- 007 (Rust scanner implementation)
- 027 (Scanner UI integration)

## Task
Ensure scan queue and Swift-based scanning do not run blocking I/O on the main actor. Keep UI updates on the main actor but move directory enumeration and `du` calls to a background context.

## Spec Reference
SPEC.md > Scanning Engine (async, non-blocking) and Core Principles > Speed.

## Implementation Details
- Remove `@MainActor` from `ScanQueue` or isolate main-thread-only properties from the scan loop.
- Run the scan loop in a background task (`Task.detached` or a dedicated actor) so `FileManager` enumeration and `Process.waitUntilExit` are not executed on the main thread.
- Gate UI-bound state updates (`isScanning`, `currentTask`, `queuedCount`, `progress`, callbacks) behind `MainActor.run { ... }`.
- Keep `scanQueue` public API stable (prioritize/enqueue/reset) but make sure those methods only touch thread-safe state or hop to the scan actor.
- Ensure cancellation works correctly (Task cancellation stops scanning promptly).

## Files to Create/Modify
- `DiskSpice/DiskSpice/Services/ScanQueue.swift` - move scan loop off main actor and marshal UI updates onto `MainActor`.
- `DiskSpice/DiskSpice/Services/SwiftScanner.swift` - ensure `getDirectorySizeWithDu` and directory enumeration are invoked off main (no `waitUntilExit` on main thread).

## Acceptance Criteria
- [ ] `ScanQueue.scanLoop()` is no longer executed on the main actor.
- [ ] Any UI-facing properties are updated on the main actor only.
- [ ] Scrolling and navigation remain responsive while scanning large directories.
- [ ] Scans can be cancelled without hanging the UI thread.

## Completion Promise
`<promise>TICKET_054_COMPLETE</promise>`
