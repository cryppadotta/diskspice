# 005: Add Concurrent Scanning With Backpressure

## Dependencies
- 001

## Task
Allow multiple directory scans in flight with a bounded concurrency limit and backpressure to avoid UI stalls.

## Spec Reference
SPEC.md > Scanning Engine; SPEC.md > Core Principles (Speed)

## Implementation Details
- Add a configurable max concurrent scan count.
- Use async tasks to scan multiple directories in parallel.
- Apply backpressure by pausing queue growth when the worker is saturated.

## Files to Create/Modify
- `DiskSpice/DiskSpice/Services/ScanQueue.swift` - Concurrent scan loop and throttling.

## Acceptance Criteria
- [ ] Multiple directory scans can run simultaneously up to a fixed limit.
- [ ] Queue growth is throttled when concurrency is saturated.
- [ ] App compiles without errors.

## Completion Promise
`<promise>TICKET_005_COMPLETE</promise>`
