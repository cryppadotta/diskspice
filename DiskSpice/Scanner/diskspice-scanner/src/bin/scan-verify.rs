use diskspice_scanner::compute_directory_totals;
use std::env;
use std::path::PathBuf;
use std::process::Command;

fn human_bytes(bytes: u64) -> String {
    const UNITS: [&str; 5] = ["B", "KB", "MB", "GB", "TB"];
    let mut size = bytes as f64;
    let mut unit = 0usize;
    while size >= 1024.0 && unit + 1 < UNITS.len() {
        size /= 1024.0;
        unit += 1;
    }
    format!("{:.1} {}", size, UNITS[unit])
}

fn du_size_bytes(path: &str) -> Option<u64> {
    let output = Command::new("/usr/bin/du")
        .arg("-sk")
        .arg(path)
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let stdout = String::from_utf8_lossy(&output.stdout);
    let size_kb = stdout.split_whitespace().next()?.parse::<u64>().ok()?;
    Some(size_kb * 1024)
}

fn main() {
    let path = env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."));

    let totals = match compute_directory_totals(&path) {
        Ok(totals) => totals,
        Err(err) => {
            eprintln!("scan-verify: failed to scan {}: {}", path.display(), err);
            std::process::exit(1);
        }
    };

    let du_bytes = du_size_bytes(path.to_string_lossy().as_ref());

    println!("Path: {}", path.display());
    println!(
        "Scanner total: {} ({}), items: {}",
        totals.total_size,
        human_bytes(totals.total_size),
        totals.total_items
    );
    match du_bytes {
        Some(bytes) => {
            let delta = if bytes > totals.total_size {
                bytes - totals.total_size
            } else {
                totals.total_size - bytes
            };
            let delta_pct = if bytes == 0 {
                0.0
            } else {
                (delta as f64 / bytes as f64) * 100.0
            };
            println!("du -sk: {} ({})", bytes, human_bytes(bytes));
            println!("Delta: {} ({}%)", human_bytes(delta), delta_pct.round());
        }
        None => println!("du -sk: unavailable"),
    }
}
