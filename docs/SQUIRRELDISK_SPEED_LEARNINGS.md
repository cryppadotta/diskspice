# SquirrelDisk speed learnings and borrowable ideas

Source: https://github.com/adileo/squirreldisk (inspected in `.tmp/squirreldisk`).

## What looks fast in SquirrelDisk (evidence)

- Parallel, native scanner via Rust sidecar: `parallel-disk-usage` is used as a Tauri sidecar (`src-tauri/src/scan.rs`) to do the heavy traversal and emit JSON output.
- Sampling for quick scans: the UI defaults to `ratio: "0.001"` unless "full scan" is chosen (`src/components/DiskDetail.tsx`), and the scanner translates it to `--min-ratio` (`src-tauri/src/scan.rs`).
- Progress from stderr while scan runs: the sidecar emits progress lines parsed by regex and forwarded as `scan_status` events (`src-tauri/src/scan.rs`), so the UI can show percent while the scan is still running.
- Avoids known slow/duplicate mounts: root scans skip system directories (e.g., `/System`, `/dev`, `/Volumes`) in the sidecar (`src-tauri/src/scan.rs`), and the disk list hides certain duplicate mounts (e.g., `/System/Volumes/Data`) (`src/components/DiskList.tsx`).
- Minimal UI work until data ready: the UI stays in a loading view and only builds the D3 sunburst after the full tree arrives (`src/components/DiskDetail.tsx`).

## Why this feels fast (takeaways)

- Sampling defaults give a quick first answer while keeping a full scan as an opt-in slower path.
- Parallel traversal is delegated to Rust (and `parallel-disk-usage` uses `rayon` internally) instead of UI-thread scanning.
- Progress reporting is decoupled from the full result; the UI can animate and reassure quickly.
- System path filtering avoids wasted work and permission-related slowdowns.

## Borrowable ideas for DiskSpice

1. Default to a "fast scan" sampling ratio with a clear toggle for a full scan.
2. Keep progress visible immediately: report items/bytes scanned at a steady cadence even if the full tree isn’t ready.
3. Make system/duplicate volume exclusions explicit and consistent across discovery + scan.
4. Consider a “fast preview” mode that shows top-level directories early, then fills in deeper levels.
5. Keep the UI work on scan completion light: reuse cached layout data and progressively refine.

## Proposed plan (DiskSpice-focused)

### Phase 1: quick wins (feel faster)
- Add a default sampling ratio to the Rust scanner path (if not already) and expose a UI toggle for full scan.
- Cap progress using used-space like SquirrelDisk’s `min(total, used)` logic to avoid 100%+ and jitter.
- Centralize “skip list” for known slow/duplicate mounts and apply it in both volume discovery and scan start.

### Phase 2: progressive results
- Emit an initial “top-level” snapshot early (root children + sizes) before the full tree is complete.
- Incrementally merge deeper nodes into the existing tree (coalesced UI updates).
- Show a soft “refining…” state once the first tree is ready to reduce perceived waiting.

### Phase 3: scanner throughput
- Evaluate tighter batching and backpressure in the Rust scanner IPC (keep payloads small, frequent).
- Compare current scanner traversal to `parallel-disk-usage` patterns (work-stealing, queue depth).
- Add a configurable max depth for “fast scan” to shorten critical path.
