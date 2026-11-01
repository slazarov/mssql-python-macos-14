#!/usr/bin/env bash
set -euo pipefail

MSSQL_DIR="${1:?Usage: $0 <mssql-python-dir>}"
MSSQL_RS_DIR="${MSSQL_RS_DIR:-/tmp/mssql-rs}"

echo "Building mssql_py_core from source (targeting macOS 14.0)..."

if [ ! -d "$MSSQL_RS_DIR/.git" ]; then
    echo "mssql-rs checkout not found at $MSSQL_RS_DIR; cloning latest main..."
    git clone --depth 1 https://github.com/microsoft/mssql-rs.git "$MSSQL_RS_DIR"
fi

MSSQL_RS_SHA="$(git -C "$MSSQL_RS_DIR" rev-parse HEAD)"
echo "Using mssql-rs commit: $MSSQL_RS_SHA"

cd "$MSSQL_RS_DIR"
rustup target add x86_64-apple-darwin

cd "$MSSQL_RS_DIR/mssql-py-core"

MACOSX_DEPLOYMENT_TARGET=14.0 maturin build --release \
    --target universal2-apple-darwin \
    --auditwheel=skip

cd "$MSSQL_DIR"

# The distribution was renamed mssql_py_core -> mssql_python_rs; the importable
# module is still mssql_py_core. Accept either wheel name.
shopt -s nullglob
wheels=("$MSSQL_RS_DIR"/mssql-py-core/target/wheels/{mssql_python_rs,mssql_py_core}-*.whl)
shopt -u nullglob
if [ "${#wheels[@]}" -ne 1 ]; then
    echo "Expected exactly one mssql-py-core wheel, found ${#wheels[@]}:" >&2
    ls -la "$MSSQL_RS_DIR"/mssql-py-core/target/wheels/ >&2 || true
    exit 1
fi

wheel="${wheels[0]}"
echo "Built mssql-py-core wheel: $(basename "$wheel")"

# Since mssql-python v1.16.0, mssql_py_core ships as the standalone
# mssql-python-rs distribution, pinned via eng/versions/mssql-python-rs.version.
# In that layout we publish the wheel itself instead of vendoring the module.
RS_VERSION_FILE="$MSSQL_DIR/eng/versions/mssql-python-rs.version"
if [ -f "$RS_VERSION_FILE" ]; then
    rs_version="$(tr -d '[:space:]' < "$RS_VERSION_FILE")"
    case "$(basename "$wheel")" in
        mssql_python_rs-"$rs_version"-*.whl) ;;
        *)
            echo "mssql-python pins mssql-python-rs==$rs_version but built $(basename "$wheel")" >&2
            exit 1
            ;;
    esac
    RS_WHEEL_DIR="${RS_WHEEL_DIR:-$MSSQL_DIR/dist-rs}"
    mkdir -p "$RS_WHEEL_DIR"
    cp "$wheel" "$RS_WHEEL_DIR/"
    echo "mssql-python-rs $rs_version wheel copied to: $RS_WHEEL_DIR"
    exit 0
fi

# Pre-v1.16.0: mssql_py_core is vendored into the mssql-python wheel.
rm -rf /tmp/mssql_py_core_extract
pip install "$wheel" --target /tmp/mssql_py_core_extract --no-deps

mkdir -p mssql_py_core
cp -r /tmp/mssql_py_core_extract/mssql_py_core/ mssql_py_core/

# mssql-rs now builds a stable-ABI extension (mssql_py_core.abi3.so), but
# upstream setup.py only packages mssql_py_core.cp*.so. Rename it to this
# interpreter's suffix so it is included; abi3 modules load under either name.
shopt -s nullglob
for so in mssql_py_core/mssql_py_core*.abi3.so; do
    ext_suffix="$(python -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')"
    mv "$so" "mssql_py_core/mssql_py_core${ext_suffix}"
    echo "Renamed $(basename "$so") -> mssql_py_core${ext_suffix}"
done
shopt -u nullglob

echo "mssql_py_core built and installed into: $MSSQL_DIR/mssql_py_core/"
ls -la mssql_py_core/
