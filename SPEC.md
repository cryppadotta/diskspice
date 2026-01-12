# DiskSpice - Mac Disk Space Manager

## Overview

A native macOS application for visualizing and managing disk space usage. Differentiates from existing tools through responsive async scanning, persistent caching, and an intuitive treemap visualization.

## Core Principles

1. **Beauty**: Premium, polished UI rivaling the best Mac apps (Sketch, Things, Fantastical level)
2. **Speed**: Instant response, background scanning, never block the UI
3. **Clarity**: Information at a glance, no clutter, progressive disclosure

## Core Requirements

### Platform
- Native macOS application
- **Minimum**: macOS 14 (Sonoma) - enables @Observable macro, latest SwiftUI
- Requires Full Disk Access permission from user
- **First launch**: Friendly permission guide explaining FDA need
  - Button to open System Preferences > Privacy
  - Wait/detect when permission granted, then start scan

### Scanning Engine
- **Default scope**: All mounted volumes (internal + external drives)
- Asynchronous, non-blocking disk traversal
- Sorts results by size as data arrives (progressive)
- **Bundled binary approach**: Fork of `dust` (Rust-based)
  - Modify to emit streaming JSON for progressive UI updates
  - Add IPC mechanism for pause/resume/cancel from Swift app
  - Treemap logic already exists in dust (potential reuse)
- Requires Full Disk Access permission
- **Error handling**: Failed folders show with error badge
  - Permission denied, disk errors, deleted folders
  - User can click to retry
- **Symlinks/hardlinks**: Show with special indicator, display target size but don't add to parent total (prevents double-counting)

### Caching & Persistence
- Results cached to disk between sessions (JSON or SQLite)
- Store last-scanned timestamp per folder
- **Startup behavior**:
  1. Immediately display cached data with "stale" indicators
  2. Automatically kick off background rescan
  3. Update UI progressively as fresh data arrives
  4. Replace stale indicators with "current" as folders complete
- Manual refresh: user can click any folder to force immediate rescan
- **Visual status indicators** (subtle, non-intrusive):
  - Stale/cached: Slightly reduced opacity/saturation
  - Scanning: Subtle pulse or shimmer animation
  - Current/fresh: Full color, no animation

### UI Framework
- **SwiftUI** for all UI components
- **SwiftUI Canvas** for treemap visualization (hardware accelerated drawing)
- Leverage modern Swift concurrency (async/await, actors)
- **Appearance**: Follow system (auto light/dark mode)

### Visual Design Goals
- Fluid 60fps animations throughout
- Subtle shadows, gradients, and depth (not flat, not skeuomorphic)
- Smooth transitions between states (avoid jarring updates)
- Typography: SF Pro with careful hierarchy
- Icons: SF Symbols, consistent weight
- Whitespace and breathing room - not cramped
- Delightful micro-interactions on hover/click

### Window Layout
- **Disk summary bar**: Top bar showing "X of Y used (Z free)" with visual progress bar
  - Always visible, updates as scans complete
- **Side-by-side**: Treemap on LEFT, List on RIGHT
- Selection syncs between both views (click in treemap highlights in list, vice versa)
- Resizable split (drag divider)
- Breadcrumbs/navigation bar below summary
- **Multi-volume display**: At root level, each mounted volume is a separate rectangle
  - Volumes sized proportionally to their used space
  - Click volume to drill into its contents

### Search
- **Search bar**: Filter and highlight matches in both treemap and list
- Matches highlighted in treemap (outline/glow)
- List filters to show only matching items
- Search within current folder or entire disk

### Navigation
- **Breadcrumbs**: Path bar showing current location (e.g., "Home > Library > Caches")
  - Click any segment to jump directly there
- **Back button**: Browser-style, maintains history stack
- **Keyboard shortcuts**: Cmd+[ or Escape to go back, Cmd+Up to go to parent
- **Click parent area**: Treemap border/margin represents parent, click to go up

### UI - List View (Right Panel)
- Sorted by size (largest first)
- **Each row shows**: Name, size, item count, last modified date
- Shows loading/scanning progress per folder
- Click to refresh individual folder
- Click to drill into folder contents
- Size bar: visual percentage indicator relative to parent folder

### UI - Treemap Visualization (Left Panel)
- **Squarified treemap algorithm** (prefers square-ish rectangles)
- Each rectangle shows: folder name, size
- Hover: highlight rectangle
- Click: drill into that folder's contents (zoom animation transition)
- **Color by file type** (comprehensive categories):
  - Video (blue), Audio (purple), Images (green)
  - Code/Source (orange), Archives (brown), Applications (red)
  - System files (gray), Cache/temp (yellow), Documents (teal)
  - Other (neutral)
- **Folder color**: Dominant file type by size within that folder
- **Depth**: 1 level (flat view) - must click to drill into subfolders
- **Small items handling**: Items below visual threshold grouped into "Other (N items, X MB)"
  - Single clickable rectangle representing aggregated small items
  - Clicking shows list view of the hidden items

### File Operations
- **Move to Trash**: Primary deletion method (safe, recoverable)
- Right-click context menu: "Move to Trash", "Reveal in Finder"
- After deletion: update sizes up the tree, animate treemap change
- **Delete during scan**: Block until folder scan completes (show message)
- **Selection**: Single item only (no multi-select)

### Exclusions
- **No hidden exclusions**: Show all folders including .git, node_modules, __pycache__
- These are often large and users may want to delete them
- Don't need to recursively drill into these (show as single block with total size)

### Smart Utilities Panel
A dedicated panel with intelligent cleanup tools:

**v1 - Initial utilities:**
- **Stale node_modules finder**: Find node_modules not accessed in X days/months
  - Show list with project name, size, last accessed date
  - Bulk select and delete

**Future utilities (extensible):**
- Old Xcode derived data / iOS simulators
- Unused Homebrew cache
- Old Docker images/volumes
- Duplicate large files
- Old downloads
- Cache clearers (various apps)

### Distribution
- Regular dock application (no menu bar presence)
- **Direct download only** (website/GitHub releases)
  - No App Store sandboxing restrictions
  - Full Disk Access without limitations
  - Notarized for Gatekeeper

## Out of Scope (v1)

- **No cloud storage integration**: iCloud, Dropbox, Google Drive - local disks only
- **No scheduled scans**: Manual and on-launch scanning only, no background daemon
- **No AI recommendations**: App visualizes, user decides what to delete
- **No duplicate finder**: May add later, but not v1 (complex feature)
- **No remote volumes**: Network drives, NAS, SMB shares - local only

---

*Spec finalized. Ready for implementation.*
