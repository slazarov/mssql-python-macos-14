# AGENTS.md — mssql-python-macos-14

## Project Purpose
Slim build repo that produces macOS 14 (Sonoma) compatible wheels from upstream
`microsoft/mssql-python`. The official wheels are tagged `macosx_15_0_universal2`
(macOS 15 Sequoia+ only). This repo patches the platform tag and deployment target
to support macOS 14+.

## How It Works
CI resolves the latest official upstream `microsoft/mssql-python` release, clones that
tag, applies our patches, builds `mssql_py_core` from source (from `microsoft/mssql-rs`),
patches dylibs, builds the C++ extension, and packages the wheel. No upstream source
lives in this repo.

## Repo Contents
```
patches/
  setup.py.patch      — platform tag macosx_15_0 → macosx_14_0, add plat_name_supplied
  cmake.patch         — CMAKE_OSX_DEPLOYMENT_TARGET=14.0
scripts/
  patch-dylibs.sh     — vtool + codesign ODBC dylibs to macOS 14.0
  build-mssql-py-core.sh — clone mssql-rs, maturin build, extract into place
.github/workflows/
  build-macos-wheel.yml — CI workflow
AGENTS.md
PLAN.md
.gitignore
```

## Key Patches Applied to Upstream
1. `setup.py`: `macosx_15_0_universal2` → `macosx_14_0_universal2` + `self.plat_name_supplied = True`
2. `mssql_python/pybind/CMakeLists.txt`: `CMAKE_OSX_DEPLOYMENT_TARGET=14.0`
3. `mssql_py_core` built from source with `MACOSX_DEPLOYMENT_TARGET=14.0`
4. Bundled ODBC dylibs patched with `vtool -set-build-version macos 14.0 15.0`
   (in `mssql_python_odbc/libs/macos` since upstream v1.15.0, `mssql_python/libs/macos` before)
5. Since v1.15.0, `mssql-python` pins a separate `mssql-python-odbc` package; CI builds it
   via `setup_odbc.py` with `ODBC_TARGET_PLATFORM_TAG=macosx_14_0_universal2` and releases it
   alongside the per-Python wheels (PyPI's copy is macOS 15+ only)

## CI/CD
- `.github/workflows/build-macos-wheel.yml` — builds on `macos-14` runner (M1, Sonoma)
- Python matrix: `[3.10, 3.11, 3.12, 3.13, 3.14]`
- Upstream: builds latest official `microsoft/mssql-python` release tag
- Automation: daily schedule publishes only missing `vX.Y.Z-macos14` releases
- Pushes do not trigger wheel builds; use schedule or manual workflow dispatch

## Known Risk
- If upstream renames files we patch, CI fails on `patch` — visible immediately
- Bundled ODBC dylibs ship with `minos 15.0`, patched to `14.0` via `vtool`
- If dylib runtime crashes occur on macOS 14, Microsoft needs to provide macOS 14 binaries

## Local Build
```bash
# Clone latest upstream release
UPSTREAM_TAG="$(curl -fsSL https://api.github.com/repos/microsoft/mssql-python/releases/latest \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])')"

# Or choose a specific upstream version:
# UPSTREAM_TAG=v1.8.0

git clone --depth 1 --branch "$UPSTREAM_TAG" https://github.com/microsoft/mssql-python.git /tmp/mssql-python

# Apply patches
patch -d /tmp/mssql-python -p1 < patches/setup.py.patch
patch -d /tmp/mssql-python -p1 < patches/cmake.patch

# Install deps
brew install unixodbc
pip install setuptools wheel cmake pybind11 maturin

# Build
scripts/build-mssql-py-core.sh /tmp/mssql-python
scripts/patch-dylibs.sh /tmp/mssql-python
cd /tmp/mssql-python/mssql_python/pybind && chmod +x build.sh configure_dylibs.sh && ./build.sh
cd /tmp/mssql-python && python setup.py bdist_wheel
# v1.15.0+: ODBC driver wheel
ODBC_TARGET_PLATFORM_TAG=macosx_14_0_universal2 ODBC_TARGET_ARCH=universal2 \
  python setup_odbc.py bdist_wheel --dist-dir dist-odbc
```
