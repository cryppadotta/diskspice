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
