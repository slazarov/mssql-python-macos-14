#!/usr/bin/env bash
set -euo pipefail

MSSQL_DIR="${1:?Usage: $0 <mssql-python-dir>}"
MSSQL_RS_DIR="${MSSQL_RS_DIR:-/tmp/mssql-rs}"

echo "Building mssql_py_core from source (targeting macOS 14.0)..."

if [ ! -d "$MSSQL_RS_DIR/.git" ]; then
    git clone --depth 1 https://github.com/microsoft/mssql-rs.git "$MSSQL_RS_DIR"
fi

cd "$MSSQL_RS_DIR"

rustup target add x86_64-apple-darwin

cd "$MSSQL_RS_DIR/mssql-py-core"

MACOSX_DEPLOYMENT_TARGET=14.0 maturin build --release \
    --target universal2-apple-darwin \
    --auditwheel=skip

cd "$MSSQL_DIR"

pip install "$MSSQL_RS_DIR"/mssql-py-core/target/wheels/mssql_py_core-*.whl \
    --target /tmp/mssql_py_core_extract --no-deps

mkdir -p mssql_py_core
cp -r /tmp/mssql_py_core_extract/mssql_py_core/ mssql_py_core/

echo "mssql_py_core built and installed into: $MSSQL_DIR/mssql_py_core/"
ls -la mssql_py_core/
