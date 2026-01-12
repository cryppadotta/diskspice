# 008: Add IPC Control Mechanism to Rust Scanner

## Dependencies
- 007 (Rust scanner implementation)

## Task
Add stdin-based IPC to allow the Swift app to send control commands (pause, resume, cancel, refresh) to the running scanner process.

## Spec Reference
See SPEC.md > Scanning Engine: "Add IPC mechanism for pause/resume/cancel from Swift app"

## Implementation Details

### Update scanner.rs with control channel

```rust
use crossbeam_channel::{bounded, Receiver, Sender, TryRecvError};
use std::io::{self, BufRead, BufWriter, Write};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;

#[derive(Debug, Clone)]
pub enum ControlCommand {
    Pause,
    Resume,
    Cancel,
    Refresh(String), // path to refresh
}

pub struct Scanner {
    writer: BufWriter<io::Stdout>,
    paused: Arc<AtomicBool>,
    cancelled: Arc<AtomicBool>,
    control_rx: Option<Receiver<ControlCommand>>,
}

impl Scanner {
    pub fn new() -> Self {
        Scanner {
            writer: BufWriter::new(io::stdout()),
            paused: Arc::new(AtomicBool::new(false)),
            cancelled: Arc::new(AtomicBool::new(false)),
            control_rx: None,
        }
    }

    pub fn with_control_channel() -> (Self, Sender<ControlCommand>) {
        let (tx, rx) = bounded(16);
        let scanner = Scanner {
            writer: BufWriter::new(io::stdout()),
            paused: Arc::new(AtomicBool::new(false)),
            cancelled: Arc::new(AtomicBool::new(false)),
            control_rx: Some(rx),
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
        if let Some(ref rx) = self.control_rx {
            loop {
                match rx.try_recv() {
                    Ok(ControlCommand::Pause) => {
                        self.paused.store(true, Ordering::Relaxed);
                        self.emit(ScanMessage::Status {
                            status: "paused".to_string(),
                        });
                    }
                    Ok(ControlCommand::Resume) => {
                        self.paused.store(false, Ordering::Relaxed);
                        self.emit(ScanMessage::Status {
                            status: "resumed".to_string(),
                        });
                    }
                    Ok(ControlCommand::Cancel) => {
                        self.cancelled.store(true, Ordering::Relaxed);
                        self.emit(ScanMessage::Status {
                            status: "cancelled".to_string(),
                        });
                    }
                    Ok(ControlCommand::Refresh(path)) => {
                        self.emit(ScanMessage::Status {
                            status: format!("refreshing:{}", path),
                        });
                        // Refresh will be handled by caller
                    }
                    Err(TryRecvError::Empty) => break,
                    Err(TryRecvError::Disconnected) => break,
                }
            }
        }
    }

    // ... existing scan methods, but add check_control() calls in loops
}

// Add Status variant to ScanMessage
#[derive(Debug, Serialize, Deserialize)]
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
```

### Update main.rs with stdin command reader

```rust
use diskspice_scanner::{ControlCommand, Scanner};
use std::io::{self, BufRead};
use std::thread;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let path = args.get(1).map(|s| s.as_str()).unwrap_or(".");

    let (mut scanner, control_tx) = Scanner::with_control_channel();

    // Spawn thread to read stdin for commands
    let stdin_tx = control_tx.clone();
    thread::spawn(move || {
        let stdin = io::stdin();
        for line in stdin.lock().lines() {
            if let Ok(cmd) = line {
                let command = match cmd.trim() {
                    "pause" => Some(ControlCommand::Pause),
                    "resume" => Some(ControlCommand::Resume),
                    "cancel" => Some(ControlCommand::Cancel),
                    s if s.starts_with("refresh:") => {
                        Some(ControlCommand::Refresh(s[8..].to_string()))
                    }
                    _ => None,
                };
                if let Some(c) = command {
                    if stdin_tx.send(c).is_err() {
                        break;
                    }
                }
            }
        }
    });

    scanner.scan(path);
}
```

### IPC Protocol Documentation

**Commands (stdin -> scanner):**
- `pause` - Pause scanning
- `resume` - Resume scanning
- `cancel` - Cancel scan and exit
- `refresh:/path/to/folder` - Re-scan specific folder

**Responses (scanner -> stdout):**
- `{"type":"status","status":"paused"}` - Acknowledged pause
- `{"type":"status","status":"resumed"}` - Acknowledged resume
- `{"type":"status","status":"cancelled"}` - Acknowledged cancel
- `{"type":"status","status":"refreshing:/path"}` - Starting refresh

## Files to Create/Modify
- `DiskSpice/Scanner/diskspice-scanner/src/scanner.rs` - Add IPC control
- `DiskSpice/Scanner/diskspice-scanner/src/main.rs` - Add stdin reader

## Acceptance Criteria
- [ ] Scanner accepts `pause` command and pauses scanning
- [ ] Scanner accepts `resume` command and resumes scanning
- [ ] Scanner accepts `cancel` command and exits cleanly
- [ ] Scanner emits status messages for each command
- [ ] Commands are read from stdin line by line
- [ ] Pause actually pauses (no new entries emitted)
- [ ] Cancel stops scan and emits done message
- [ ] Test: `echo "pause" | ./diskspice-scan /path` pauses the scan

## Completion Promise
`<promise>TICKET_008_COMPLETE</promise>`
