# Repository Guidelines

## Project Structure & Module Organization
- `DiskSpice/` is the app workspace root.
- `DiskSpice/DiskSpice/` contains the SwiftUI app source (App, Models, Services, Views, Resources).
- `DiskSpice/DiskSpice.xcodeproj` is the Xcode project.
- `DiskSpice/Scanner/diskspice-scanner/` contains the Rust scanner crate.
- `DiskSpice/Scanner/build-scanner.sh` builds a universal macOS scanner binary.
- `DiskSpice/docs/` holds developer docs (e.g., logging).
- `plans/` and `plans/tickets/` track project planning tickets.

## Build, Test, and Development Commands
- `open DiskSpice/DiskSpice.xcodeproj` - open the app in Xcode and run from the IDE.
- `xcodebuild -project DiskSpice/DiskSpice.xcodeproj -scheme DiskSpice build` - CLI build of the macOS app.
- `./DiskSpice/Scanner/build-scanner.sh` - build the Rust scanner and produce `DiskSpice/Scanner/bin/diskspice-scan`.
- `cargo test` (in `DiskSpice/Scanner/diskspice-scanner`) - run Rust unit tests if added.

## Coding Style & Naming Conventions
- Swift: follow Swift API Design Guidelines; 4-space indentation; `UpperCamelCase` types/files, `lowerCamelCase` for vars and functions.
- Rust: `rustfmt` defaults; `snake_case` for modules/functions; `UpperCamelCase` types.
- Keep SwiftUI views small and focused; prefer single-responsibility services under `DiskSpice/DiskSpice/Services`.

## Testing Guidelines
- No dedicated Swift test target is present yet; validate changes by running the app in Xcode.
- For Rust changes, prefer adding unit tests in the crate and run `cargo test`.
- When UI changes are made, include a quick manual verification note in the PR.

## Commit & Pull Request Guidelines
- Commit format follows existing history: `Complete ticket ###: Title`.
- PRs should describe user-visible changes, link related tickets in `plans/tickets/`, and include screenshots for UI changes.

## Debugging & Logging
- Debug logs live at `~/Library/Logs/DiskSpice/debug.log`.
- See `DiskSpice/docs/DEBUGGING.md` for categories and troubleshooting steps.

## Architecture Overview
- SwiftUI app (`DiskSpice/DiskSpice`) owns state in `AppState` and routes user actions through services like `ScanCoordinator`.
- The scanner layer has two implementations: `SwiftScanner` for native traversal and `RustScanner` for the external binary.
- `RustScanner` launches the bundled `diskspice-scan` and streams results back into the app; `ScanQueue` manages scan ordering and cancellation.

## Security & Configuration Tips
- The app relies on Full Disk Access; ensure the permission flow is tested when changing scanner behavior.
