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
