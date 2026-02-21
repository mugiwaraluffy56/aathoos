#!/usr/bin/env bash
# Build the aathoos-core Rust library as a macOS universal static library.
#
# Output: macos/CoreLibs/libaathoos_core.a  (arm64 + x86_64 fat binary)
#
# Usage:
#   ./scripts/build-core-macos.sh          # from repo root
#   bash scripts/build-core-macos.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_DIR="$REPO_ROOT/core"
OUT_DIR="$REPO_ROOT/macos/CoreLibs"

echo "==> Building aathoos-core for macOS (arm64 + x86_64)"

cd "$CORE_DIR"

rustup target add aarch64-apple-darwin x86_64-apple-darwin 2>/dev/null || true

cargo build --release --lib --target aarch64-apple-darwin
cargo build --release --lib --target x86_64-apple-darwin

mkdir -p "$OUT_DIR"

lipo -create \
  "target/aarch64-apple-darwin/release/libaathoos_core.a" \
  "target/x86_64-apple-darwin/release/libaathoos_core.a" \
  -output "$OUT_DIR/libaathoos_core.a"

echo "==> Output: $OUT_DIR/libaathoos_core.a"
lipo -info "$OUT_DIR/libaathoos_core.a"
