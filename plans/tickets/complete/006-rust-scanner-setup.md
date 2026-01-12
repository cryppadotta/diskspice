# 006: Set Up Rust Scanner Project

## Dependencies
- None (can run in parallel with Swift work)

## Task
Clone the dust repository and set up a modified version as a subproject for DiskSpice's fast scanning engine.

## Spec Reference
See SPEC.md > Scanning Engine: "Fork of dust (Rust-based)"

## Implementation Details

### Clone and set up dust fork

```bash
# Create scanner directory
mkdir -p DiskSpice/Scanner
cd DiskSpice/Scanner

# Clone dust (or fork it first on GitHub)
git clone https://github.com/bootandy/dust.git dust-scanner
cd dust-scanner

# Verify it builds
cargo build --release

# Test it works
./target/release/dust ~
```

### Create wrapper Cargo project

Create a new Cargo project that wraps dust's functionality:

```bash
cd DiskSpice/Scanner
cargo new diskspice-scanner --lib
```

**Cargo.toml**:
```toml
[package]
name = "diskspice-scanner"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "staticlib"]

[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
walkdir = "2"
crossbeam-channel = "0.5"

[profile.release]
opt-level = 3
lto = true
```

### Basic project structure

```
DiskSpice/
└── Scanner/
    └── diskspice-scanner/
        ├── Cargo.toml
        ├── src/
        │   ├── lib.rs
        │   └── scanner.rs
        └── build.rs (optional, for Swift bridging)
```

**src/lib.rs** (placeholder):
```rust
mod scanner;

pub use scanner::*;
```

**src/scanner.rs** (placeholder):
```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct ScanResult {
    pub path: String,
    pub size: u64,
    pub is_dir: bool,
    pub children: Vec<ScanResult>,
}

pub fn scan_directory(path: &str) -> ScanResult {
    // Placeholder - will be implemented in ticket 007
    ScanResult {
        path: path.to_string(),
        size: 0,
        is_dir: true,
        children: vec![],
    }
}
```

## Files to Create/Modify
- `DiskSpice/Scanner/diskspice-scanner/Cargo.toml` - Cargo configuration
- `DiskSpice/Scanner/diskspice-scanner/src/lib.rs` - Library entry point
- `DiskSpice/Scanner/diskspice-scanner/src/scanner.rs` - Scanner placeholder

## Acceptance Criteria
- [ ] Rust toolchain installed (`rustc --version` works)
- [ ] Scanner directory created at DiskSpice/Scanner/
- [ ] diskspice-scanner Cargo project created
- [ ] `cargo build` succeeds in diskspice-scanner directory
- [ ] Basic ScanResult struct defined with serde serialization
- [ ] Project structure matches the specification

## Completion Promise
`<promise>TICKET_006_COMPLETE</promise>`
