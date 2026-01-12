# 055: Batch Rust Scanner Output and Stream Read Directory

## Dependencies
- 007 (Rust scanner implementation)

## Task
Improve indexing throughput by streaming `read_dir` entries without collecting them into a `Vec`, and batch stdout flushing instead of flushing per entry.

## Spec Reference
SPEC.md > Scanning Engine (responsive async scanning, progressive updates).

## Implementation Details
- In `scan_directory`, replace `collect()` with direct iteration over `fs::read_dir(path)` so entries are processed as they are read.
- Introduce a lightweight batching strategy in `emit` to avoid flushing on every JSON line:
  - Buffer writes in `BufWriter` and call `flush()` only on folder completion or every N entries (e.g., 128/256).
  - Ensure final `Done` and `FolderComplete` messages are flushed.
- Keep JSON output format unchanged so the Swift side continues to parse lines.
- Preserve control command handling (pause/resume/cancel) between entries.

## Files to Create/Modify
- `DiskSpice/Scanner/diskspice-scanner/src/scanner.rs` - stream entries and batch stdout flushes.

## Acceptance Criteria
- [ ] `scan_directory` iterates `read_dir` without collecting into a `Vec`.
- [ ] Stdout flush occurs on a batch cadence or on folder completion, not per entry.
- [ ] The Swift app still receives valid JSON lines and completes a scan successfully.

## Completion Promise
`<promise>TICKET_055_COMPLETE</promise>`
