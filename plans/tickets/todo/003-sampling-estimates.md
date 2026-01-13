# 003: Add Sampling-Based Size Estimates

## Dependencies
- 002

## Task
Use sampling heuristics to estimate sizes for very large directories without hardcoded folder lists.

## Spec Reference
SPEC.md > Scanning Engine; SPEC.md > Core Principles (Speed)

## Implementation Details
- For directories exceeding the scan budget, sample a subset of entries and estimate total size/item count.
- Store the estimate on the directory node so UI shows a plausible size during partial scans.
- Ensure estimates are replaced by exact sizes once full scanning completes.

## Files to Create/Modify
- `DiskSpice/DiskSpice/Services/SwiftScanner.swift` - Sampling logic and estimated size calculation.
- `DiskSpice/DiskSpice/App/AppState.swift` - Merge estimated sizes with later final sizes.

## Acceptance Criteria
- [ ] Very large folders show estimated sizes instead of zero or blank.
- [ ] Estimates are replaced by exact sizes when scans complete.
- [ ] App compiles without errors.

## Completion Promise
`<promise>TICKET_003_COMPLETE</promise>`
