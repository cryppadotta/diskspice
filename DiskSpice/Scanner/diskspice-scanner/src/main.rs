mod scanner;

use scanner::{ControlCommand, Scanner};
use std::env;
use std::io::{self, BufRead};
use std::thread;

fn main() {
    let args: Vec<String> = env::args().collect();
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
