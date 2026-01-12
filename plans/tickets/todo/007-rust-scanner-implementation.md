# 007: Implement Rust Scanner with Streaming Output

## Dependencies
- 006 (Rust scanner setup)

## Task
Implement the core directory scanning logic in Rust with streaming JSON output for progressive UI updates.

## Spec Reference
See SPEC.md > Scanning Engine: "Modify to emit streaming JSON for progressive UI updates"

## Implementation Details

### Update scanner.rs with full implementation

```rust
use serde::{Deserialize, Serialize};
use std::fs;
use std::io::{self, BufWriter, Write};
use std::path::Path;
use std::time::SystemTime;
use walkdir::WalkDir;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileEntry {
    pub path: String,
    pub name: String,
    pub size: u64,
    pub is_dir: bool,
    pub is_symlink: bool,
    pub modified: Option<u64>, // Unix timestamp
    pub item_count: u64,
    pub file_type: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ScanMessage {
    #[serde(rename = "entry")]
    Entry(FileEntry),
    #[serde(rename = "complete")]
    FolderComplete { path: String, total_size: u64 },
    #[serde(rename = "error")]
    Error { path: String, message: String },
    #[serde(rename = "done")]
    Done { total_size: u64, total_items: u64 },
}

pub struct Scanner {
    writer: BufWriter<io::Stdout>,
}

impl Scanner {
    pub fn new() -> Self {
        Scanner {
            writer: BufWriter::new(io::stdout()),
        }
    }

    pub fn scan(&mut self, root_path: &str) {
        let path = Path::new(root_path);
        if !path.exists() {
            self.emit_error(root_path, "Path does not exist");
            return;
        }

        let (total_size, total_items) = self.scan_directory(path);

        self.emit(ScanMessage::Done {
            total_size,
            total_items,
        });
    }

    fn scan_directory(&mut self, path: &Path) -> (u64, u64) {
        let mut total_size: u64 = 0;
        let mut total_items: u64 = 0;

        let entries: Vec<_> = match fs::read_dir(path) {
            Ok(entries) => entries.filter_map(|e| e.ok()).collect(),
            Err(e) => {
                self.emit_error(&path.display().to_string(), &e.to_string());
                return (0, 0);
            }
        };

        for entry in entries {
            let entry_path = entry.path();
            let metadata = match entry.metadata() {
                Ok(m) => m,
                Err(e) => {
                    self.emit_error(&entry_path.display().to_string(), &e.to_string());
                    continue;
                }
            };

            let is_symlink = entry.file_type().map(|ft| ft.is_symlink()).unwrap_or(false);
            let is_dir = metadata.is_dir();

            let (size, item_count) = if is_dir && !is_symlink {
                self.scan_directory(&entry_path)
            } else {
                (metadata.len(), 1)
            };

            let modified = metadata
                .modified()
                .ok()
                .and_then(|t| t.duration_since(SystemTime::UNIX_EPOCH).ok())
                .map(|d| d.as_secs());

            let file_type = self.detect_file_type(&entry_path);

            let file_entry = FileEntry {
                path: entry_path.display().to_string(),
                name: entry_path
                    .file_name()
                    .map(|n| n.to_string_lossy().to_string())
                    .unwrap_or_default(),
                size,
                is_dir,
                is_symlink,
                modified,
                item_count,
                file_type,
            };

            self.emit(ScanMessage::Entry(file_entry));

            total_size += size;
            total_items += item_count;
        }

        self.emit(ScanMessage::FolderComplete {
            path: path.display().to_string(),
            total_size,
        });

        (total_size, total_items)
    }

    fn detect_file_type(&self, path: &Path) -> String {
        let ext = path
            .extension()
            .map(|e| e.to_string_lossy().to_lowercase())
            .unwrap_or_default();

        match ext.as_str() {
            "mp4" | "mov" | "avi" | "mkv" | "wmv" | "flv" | "webm" => "video",
            "mp3" | "wav" | "aac" | "flac" | "ogg" | "m4a" => "audio",
            "jpg" | "jpeg" | "png" | "gif" | "bmp" | "svg" | "webp" | "heic" => "image",
            "swift" | "rs" | "js" | "ts" | "py" | "rb" | "go" | "java" | "c" | "cpp" | "h" => "code",
            "zip" | "tar" | "gz" | "rar" | "7z" | "dmg" | "iso" => "archive",
            "app" | "exe" | "dll" | "so" | "dylib" => "application",
            "plist" | "dylib" | "kext" => "system",
            "cache" | "tmp" | "log" => "cache",
            "pdf" | "doc" | "docx" | "txt" | "md" | "rtf" | "xls" | "xlsx" => "document",
            _ => "other",
        }
        .to_string()
    }

    fn emit(&mut self, message: ScanMessage) {
        if let Ok(json) = serde_json::to_string(&message) {
            writeln!(self.writer, "{}", json).ok();
            self.writer.flush().ok();
        }
    }

    fn emit_error(&mut self, path: &str, message: &str) {
        self.emit(ScanMessage::Error {
            path: path.to_string(),
            message: message.to_string(),
        });
    }
}
```

### Update lib.rs with C-compatible entry point

```rust
mod scanner;

use std::ffi::CStr;
use std::os::raw::c_char;

pub use scanner::*;

/// C-compatible entry point for scanning
/// # Safety
/// path must be a valid null-terminated C string
#[no_mangle]
pub unsafe extern "C" fn scan_path(path: *const c_char) {
    let c_str = CStr::from_ptr(path);
    if let Ok(path_str) = c_str.to_str() {
        let mut scanner = Scanner::new();
        scanner.scan(path_str);
    }
}
```

### Create main.rs for CLI testing

```rust
use diskspice_scanner::Scanner;
use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    let path = args.get(1).map(|s| s.as_str()).unwrap_or(".");

    let mut scanner = Scanner::new();
    scanner.scan(path);
}
```

Update **Cargo.toml** to include binary:
```toml
[[bin]]
name = "diskspice-scan"
path = "src/main.rs"
```

## Files to Create/Modify
- `DiskSpice/Scanner/diskspice-scanner/src/scanner.rs` - Full scanner implementation
- `DiskSpice/Scanner/diskspice-scanner/src/lib.rs` - C-compatible entry point
- `DiskSpice/Scanner/diskspice-scanner/src/main.rs` - CLI binary for testing
- `DiskSpice/Scanner/diskspice-scanner/Cargo.toml` - Add binary target

## Acceptance Criteria
- [ ] Scanner emits streaming JSON lines to stdout
- [ ] Each file/folder emits an "entry" message with path, size, type
- [ ] Folders emit "complete" message when done
- [ ] Errors emit "error" message with path and reason
- [ ] Final "done" message includes total size and item count
- [ ] File type detection works for common extensions
- [ ] Symlinks are detected and marked (not followed recursively)
- [ ] `cargo run -- /some/path` produces valid JSON output
- [ ] Project builds with `cargo build --release`

## Completion Promise
`<promise>TICKET_007_COMPLETE</promise>`
