# mssql-python-macos-14

Builds macOS 14 (Sonoma) compatible wheels from upstream
[microsoft/mssql-python](https://github.com/microsoft/mssql-python).

The official wheels are tagged `macosx_15_0_universal2` (macOS 15 Sequoia+ only).
This repo patches the platform tag and deployment target to support macOS 14+.

## How it works

CI clones upstream at latest `main`, applies patches, builds `mssql_py_core` from
source ([microsoft/mssql-rs](https://github.com/microsoft/mssql-rs)), patches ODBC
dylibs, builds the C++ extension, and packages the wheel. No upstream source lives in
this repo.

## Downloads

Wheels are published as [GitHub Releases](../../releases) on every push to `main`.

## Patches applied

| Patch | Change |
|---|---|
| `patches/setup.py.patch` | Platform tag `macosx_15_0` → `macosx_14_0`, `plat_name_supplied = True` |
| `patches/cmake.patch` | `CMAKE_OSX_DEPLOYMENT_TARGET=14.0` |
| `scripts/patch-dylibs.sh` | `vtool` + codesign ODBC dylibs to macOS 14.0 |
| `scripts/build-mssql-py-core.sh` | Build Rust extension with `MACOSX_DEPLOYMENT_TARGET=14.0` |

## Install

```bash
pip install mssql_python-1.6.0-cp313-cp313-macosx_14_0_universal2.whl
```

## Local build

```bash
git clone --depth 1 https://github.com/microsoft/mssql-python.git /tmp/mssql-python
patch -d /tmp/mssql-python -p1 < patches/setup.py.patch
patch -d /tmp/mssql-python -p1 < patches/cmake.patch
brew install unixodbc
pip install setuptools wheel cmake pybind11 maturin
scripts/build-mssql-py-core.sh /tmp/mssql-python
scripts/patch-dylibs.sh /tmp/mssql-python
cd /tmp/mssql-python/mssql_python/pybind && chmod +x build.sh configure_dylibs.sh && ./build.sh
cd /tmp/mssql-python && python setup.py bdist_wheel
```

## Risk

- If upstream renames files we patch, CI fails on `patch` — visible immediately
- Bundled ODBC dylibs ship with `minos 15.0`, patched to `14.0` via `vtool`
- If dylib runtime crashes occur on macOS 14, Microsoft needs to provide macOS 14 binaries
