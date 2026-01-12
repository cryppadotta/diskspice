# 009: Build Universal Scanner Binary for macOS

## Dependencies
- 008 (Rust scanner IPC)

## Task
Build the Rust scanner as a universal binary (arm64 + x86_64) for macOS and set up the build script for inclusion in the Xcode project.

## Spec Reference
See SPEC.md > Scanning Engine: "Bundled binary approach"

## Implementation Details

### Create build script

**DiskSpice/Scanner/build-scanner.sh**:
```bash
#!/bin/bash
set -e

cd "$(dirname "$0")/diskspice-scanner"

echo "Building diskspice-scanner for macOS..."

# Build for Apple Silicon
echo "Building for arm64..."
cargo build --release --target aarch64-apple-darwin

# Build for Intel
echo "Building for x86_64..."
cargo build --release --target x86_64-apple-darwin

# Create universal binary
echo "Creating universal binary..."
mkdir -p ../bin

lipo -create \
    target/aarch64-apple-darwin/release/diskspice-scan \
    target/x86_64-apple-darwin/release/diskspice-scan \
    -output ../bin/diskspice-scan

# Verify
echo "Verifying universal binary..."
file ../bin/diskspice-scan
lipo -info ../bin/diskspice-scan

echo "Done! Binary at: Scanner/bin/diskspice-scan"
```

### Add Rust targets if needed

```bash
rustup target add aarch64-apple-darwin
rustup target add x86_64-apple-darwin
```

### Create Xcode Run Script Build Phase

In Xcode, add a Run Script build phase that runs before "Compile Sources":

```bash
# Build scanner if needed
SCANNER_DIR="${SRCROOT}/DiskSpice/Scanner"
SCANNER_BIN="${SCANNER_DIR}/bin/diskspice-scan"

if [ ! -f "$SCANNER_BIN" ] || [ "$SCANNER_DIR/diskspice-scanner/src" -nt "$SCANNER_BIN" ]; then
    echo "Building Rust scanner..."
    cd "$SCANNER_DIR"
    ./build-scanner.sh
fi

# Copy to app bundle
mkdir -p "${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Resources"
cp "$SCANNER_BIN" "${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Resources/"
```

### Update .gitignore

Add to project .gitignore:
```
# Rust build artifacts
DiskSpice/Scanner/diskspice-scanner/target/
DiskSpice/Scanner/bin/
```

### Directory structure after build

```
DiskSpice/
└── Scanner/
    ├── build-scanner.sh
    ├── bin/
    │   └── diskspice-scan (universal binary)
    └── diskspice-scanner/
        ├── Cargo.toml
        ├── src/
        └── target/ (git-ignored)
```

## Files to Create/Modify
- `DiskSpice/Scanner/build-scanner.sh` - Build script
- `.gitignore` - Add Rust build artifacts
- Xcode project - Add Run Script build phase

## Acceptance Criteria
- [ ] build-scanner.sh is executable (`chmod +x`)
- [ ] Script builds for both arm64 and x86_64 targets
- [ ] Universal binary created at Scanner/bin/diskspice-scan
- [ ] `file Scanner/bin/diskspice-scan` shows "Mach-O universal binary"
- [ ] `lipo -info` shows both architectures
- [ ] Xcode builds include the scanner binary in app bundle
- [ ] Binary is at DiskSpice.app/Contents/Resources/diskspice-scan after build
- [ ] .gitignore excludes target/ and bin/ directories

## Completion Promise
`<promise>TICKET_009_COMPLETE</promise>`
