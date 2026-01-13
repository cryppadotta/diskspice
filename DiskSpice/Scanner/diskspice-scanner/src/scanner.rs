use crossbeam_channel::{bounded, Receiver, Sender, TryRecvError};
use serde::{Deserialize, Serialize};
use std::fs;
use std::io::{self, BufWriter, Write};
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::SystemTime;

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

#[derive(Debug, Clone)]
pub enum ControlCommand {
    Pause,
    Resume,
    Cancel,
    Refresh(String), // path to refresh
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ScanMessage {
    #[serde(rename = "entry")]
    Entry(FileEntry),
    #[serde(rename = "complete")]
    FolderComplete { path: String, total_size: u64 },
    #[serde(rename = "error")]
    Error { path: String, message: String },
    #[serde(rename = "status")]
    Status { status: String },
    #[serde(rename = "done")]
    Done { total_size: u64, total_items: u64 },
}

pub struct Scanner {
    writer: BufWriter<io::Stdout>,
    paused: Arc<AtomicBool>,
    cancelled: Arc<AtomicBool>,
    control_rx: Option<Receiver<ControlCommand>>,
    pending_entries: usize,
    flush_batch_size: usize,
}

#[derive(Debug, Clone, Copy)]
pub struct ScanTotals {
    pub total_size: u64,
    pub total_items: u64,
}

impl Scanner {
    pub fn new() -> Self {
        Scanner {
            writer: BufWriter::new(io::stdout()),
            paused: Arc::new(AtomicBool::new(false)),
            cancelled: Arc::new(AtomicBool::new(false)),
            control_rx: None,
            pending_entries: 0,
            flush_batch_size: 256,
        }
    }

    pub fn with_control_channel() -> (Self, Sender<ControlCommand>) {
        let (tx, rx) = bounded(16);
        let scanner = Scanner {
            writer: BufWriter::new(io::stdout()),
            paused: Arc::new(AtomicBool::new(false)),
            cancelled: Arc::new(AtomicBool::new(false)),
            control_rx: Some(rx),
            pending_entries: 0,
            flush_batch_size: 256,
        };
        (scanner, tx)
    }

    /// Check for control commands and handle them
    fn check_control(&mut self) -> bool {
        if self.cancelled.load(Ordering::Relaxed) {
            return false; // Signal to stop
        }

        // Spin while paused
        while self.paused.load(Ordering::Relaxed) {
            self.process_commands();
            if self.cancelled.load(Ordering::Relaxed) {
                return false;
            }
            thread::sleep(std::time::Duration::from_millis(50));
        }

        self.process_commands();
        !self.cancelled.load(Ordering::Relaxed)
    }

    fn process_commands(&mut self) {
        // First, collect all commands to avoid borrowing issues
        let commands: Vec<ControlCommand> = if let Some(ref rx) = self.control_rx {
            let mut cmds = Vec::new();
            loop {
                match rx.try_recv() {
                    Ok(cmd) => cmds.push(cmd),
                    Err(TryRecvError::Empty) => break,
                    Err(TryRecvError::Disconnected) => break,
                }
            }
            cmds
        } else {
            Vec::new()
        };

        // Now process the collected commands
        for cmd in commands {
            match cmd {
                ControlCommand::Pause => {
                    self.paused.store(true, Ordering::Relaxed);
                    self.emit(ScanMessage::Status {
                        status: "paused".to_string(),
                    });
                }
                ControlCommand::Resume => {
                    self.paused.store(false, Ordering::Relaxed);
                    self.emit(ScanMessage::Status {
                        status: "resumed".to_string(),
                    });
                }
                ControlCommand::Cancel => {
                    self.cancelled.store(true, Ordering::Relaxed);
                    self.emit(ScanMessage::Status {
                        status: "cancelled".to_string(),
                    });
                }
                ControlCommand::Refresh(path) => {
                    self.emit(ScanMessage::Status {
                        status: format!("refreshing:{}", path),
                    });
                    // Refresh will be handled by caller
                }
            }
        }
    }

    pub fn scan(&mut self, root_path: &str) {
        let path = Path::new(root_path);
        if !path.exists() {
            self.emit_error(root_path, "Path does not exist");
            return;
        }

        let (total_size, total_items) = self.scan_directory(path, true);

        self.emit(ScanMessage::Done {
            total_size,
            total_items,
        });
    }

    fn scan_directory(&mut self, path: &Path, emit_entries: bool) -> (u64, u64) {
        let mut total_size: u64 = 0;
        let mut total_items: u64 = 0;

        // Check for control commands at the start of each directory
        if !self.check_control() {
            return (0, 0);
        }

        let entries = match fs::read_dir(path) {
            Ok(entries) => entries,
            Err(e) => {
                if emit_entries {
                    self.emit_error(&path.display().to_string(), &e.to_string());
                }
                return (0, 0);
            }
        };

        for entry in entries {
            let entry = match entry {
                Ok(entry) => entry,
                Err(e) => {
                    self.emit_error(&path.display().to_string(), &e.to_string());
                    continue;
                }
            };
            // Check for control commands during iteration
            if !self.check_control() {
                return (total_size, total_items);
            }

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
                self.scan_directory(&entry_path, emit_entries)
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

            if emit_entries {
                self.emit_entry(file_entry);
            }

            total_size += size;
            total_items += item_count;
        }

        if emit_entries {
            self.emit(ScanMessage::FolderComplete {
                path: path.display().to_string(),
                total_size,
            });
        }

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
            "plist" | "kext" => "system",
            "cache" | "tmp" | "log" => "cache",
            "pdf" | "doc" | "docx" | "txt" | "md" | "rtf" | "xls" | "xlsx" => "document",
            _ => "other",
        }
        .to_string()
    }

    fn emit(&mut self, message: ScanMessage) {
        self.write_message(message, true);
    }

    fn emit_entry(&mut self, entry: FileEntry) {
        self.write_message(ScanMessage::Entry(entry), false);
    }

    fn write_message(&mut self, message: ScanMessage, force_flush: bool) {
        if let Ok(json) = serde_json::to_string(&message) {
            writeln!(self.writer, "{}", json).ok();
            if force_flush {
                self.pending_entries = 0;
                self.writer.flush().ok();
            } else {
                self.pending_entries += 1;
                if self.pending_entries >= self.flush_batch_size {
                    self.pending_entries = 0;
                    self.writer.flush().ok();
                }
            }
        }
    }

    fn emit_error(&mut self, path: &str, message: &str) {
        self.emit(ScanMessage::Error {
            path: path.to_string(),
            message: message.to_string(),
        });
    }
}

impl Default for Scanner {
    fn default() -> Self {
        Self::new()
    }
}

pub fn compute_directory_totals(path: &Path) -> io::Result<ScanTotals> {
    if !path.exists() {
        return Err(io::Error::new(
            io::ErrorKind::NotFound,
            "Path does not exist",
        ));
    }

    let mut scanner = Scanner::new();
    let (total_size, total_items) = scanner.scan_directory(path, false);
    Ok(ScanTotals {
        total_size,
        total_items,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::{self, File};
    use std::io::Write;
    use std::os::unix::fs as unix_fs;
    use std::path::PathBuf;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn create_temp_dir(test_name: &str) -> PathBuf {
        let mut path = std::env::temp_dir();
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        path.push(format!(
            "diskspice_scanner_test_{}_{}_{}",
            test_name,
            std::process::id(),
            nanos
        ));
        fs::create_dir_all(&path).expect("create temp dir");
        path
    }

    fn write_bytes(path: &Path, size: usize) {
        let mut file = File::create(path).expect("create file");
        let buffer = vec![0u8; size];
        file.write_all(&buffer).expect("write bytes");
    }

    #[test]
    fn scan_directory_sums_nested_files() {
        let root = create_temp_dir("nested");
        write_bytes(&root.join("a.txt"), 10);
        fs::create_dir_all(root.join("sub")).expect("create subdir");
        write_bytes(&root.join("sub/b.bin"), 20);

        let mut scanner = Scanner::new();
        let (total_size, total_items) = scanner.scan_directory(&root, false);

        assert_eq!(total_size, 30);
        assert_eq!(total_items, 2);

        fs::remove_dir_all(root).expect("cleanup");
    }

    #[test]
    fn scan_directory_does_not_recurse_symlinked_dir() {
        let root = create_temp_dir("symlink");
        fs::create_dir_all(root.join("target")).expect("create target");
        write_bytes(&root.join("target/inside.txt"), 8);
        unix_fs::symlink(root.join("target"), root.join("link")).expect("symlink");

        let mut scanner = Scanner::new();
        let (_total_size, total_items) = scanner.scan_directory(&root, false);

        assert_eq!(total_items, 2, "counts only file + symlink entry");

        fs::remove_dir_all(root).expect("cleanup");
    }

    #[test]
    fn compute_directory_totals_requires_existing_path() {
        let mut missing = std::env::temp_dir();
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        missing.push(format!(
            "diskspice_scanner_missing_{}_{}",
            std::process::id(),
            nanos
        ));
        let result = compute_directory_totals(&missing);
        assert!(result.is_err());
    }
}
