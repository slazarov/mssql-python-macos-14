#!/usr/bin/env bash
set -euo pipefail

MSSQL_DIR="${1:?Usage: $0 <mssql-python-dir>}"

echo "Patching ODBC dylib deployment targets to macOS 14.0 in: $MSSQL_DIR"

# Since v1.15.0 the ODBC driver ships in the separate mssql_python_odbc package;
# older releases bundle it under mssql_python/libs.
if [ -d "$MSSQL_DIR/mssql_python_odbc/libs/macos" ]; then
    LIBS_DIR="$MSSQL_DIR/mssql_python_odbc/libs/macos"
else
    LIBS_DIR="$MSSQL_DIR/mssql_python/libs/macos"
fi

shopt -s nullglob
dylibs=("$LIBS_DIR"/arm64/lib/*.dylib "$LIBS_DIR"/x86_64/lib/*.dylib)
shopt -u nullglob
if [ "${#dylibs[@]}" -eq 0 ]; then
    echo "ERROR: no ODBC dylibs found under $LIBS_DIR" >&2
    exit 1
fi

for f in "${dylibs[@]}"; do
    tmpf=$(mktemp)
    echo "  Patching: ${f#"$MSSQL_DIR"/}"
    vtool -set-build-version macos 14.0 15.0 -output "$tmpf" "$f"
    mv "$tmpf" "$f"
    codesign --force --sign - "$f"
done

echo "Done patching ${#dylibs[@]} dylibs."
