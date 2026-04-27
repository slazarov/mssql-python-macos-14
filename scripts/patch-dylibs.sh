#!/usr/bin/env bash
set -euo pipefail

MSSQL_DIR="${1:?Usage: $0 <mssql-python-dir>}"

echo "Patching ODBC dylib deployment targets to macOS 14.0 in: $MSSQL_DIR"

for f in "$MSSQL_DIR"/mssql_python/libs/macos/arm64/lib/*.dylib \
         "$MSSQL_DIR"/mssql_python/libs/macos/x86_64/lib/*.dylib; do
    [ -f "$f" ] || { echo "WARNING: no dylibs found at $f"; continue; }
    tmpf=$(mktemp)
    echo "  Patching: $(basename "$f")"
    vtool -set-build-version macos 14.0 15.0 -output "$tmpf" "$f"
    mv "$tmpf" "$f"
    codesign --force --sign - "$f"
done

echo "Done patching dylibs."
