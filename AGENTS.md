# AGENTS.md — mssql-python-macos-14

## Project Purpose
Fork of microsoft/mssql-python that produces macOS 14 (Sonoma) compatible wheels.
The official upstream wheels are tagged `macosx_15_0_universal2` (macOS 15 Sequoia+ only),
making them uninstallable on macOS 14 Sonoma. This fork changes the platform tag and
deployment target to support macOS 14+.

## Key Differences from Upstream
- `setup.py` L37: platform tag `macosx_15_0` → `macosx_14_0`
- `setup.py` `CustomBdistWheel`: added `self.plat_name_supplied = True` so the wheel
  tool uses our tag instead of recalculating from binary inspection
- `mssql_python/pybind/CMakeLists.txt`: `CMAKE_OSX_DEPLOYMENT_TARGET=14.0`
- `mssql_py_core` is built **from source** (https://github.com/microsoft/mssql-rs)
  using `maturin` with `MACOSX_DEPLOYMENT_TARGET=14.0` instead of downloading the
  pre-compiled binary from Microsoft's NuGet feed
- Bundled ODBC dylibs (`mssql_python/libs/macos/*/lib/*.dylib`) are patched with
  `vtool -set-build-version macos 14.0 15.0` to rewrite `minos` from 15.0 to 14.0

**Do NOT change** `eng/scripts/install-mssql-py-core.sh` or `.ps1` — they must keep
`macosx_15_0_universal2` because that's the only tag available in Microsoft's NuGet feed.
(These scripts are no longer called by our build but must stay compatible for upstream sync.)

## Build System
- **mssql_py_core**: Built from source at `microsoft/mssql-rs` (Rust/PyO3, using `maturin`)
  with `MACOSX_DEPLOYMENT_TARGET=14.0`
- **C++ extension**: pybind11 + CMake → `ddbc_bindings.cp3XX-universal2.so`
- **Bundled dylibs**: ODBC driver in `mssql_python/libs/macos/{arm64,x86_64}/lib/`
  (patched with `vtool` to target macOS 14.0)
- **Output**: `.whl` files via `python setup.py bdist_wheel`

## CI Status & Known Issues (as of commit 818d9f1)

### Resolved
- **YAML indentation**: `merge-multiple` was outside `with:` block in download-artifact
- **Rust x86_64 target**: mssql-rs has `rust-toolchain.toml` pinning Rust 1.90 which
  overrides `dtolnay/rust-toolchain@stable`. Fix: run `rustup target add x86_64-apple-darwin`
  inside `/tmp/mssql-rs` after cloning (so rustup picks up the 1.90 toolchain).
- **`sql.h` not found**: C++ build fails because `unixodbc` is not installed on CI runner.
  Fixed by adding `unixodbc` to `brew install` step.
- **`mssql_py_core/` not found**: `cd -` in CI returned to `/tmp/mssql-rs` instead of
  `$GITHUB_WORKSPACE`. Fixed by using `cd "$GITHUB_WORKSPACE"`.
- **Python matrix**: Restored to `["3.10", "3.11", "3.12", "3.13"]` after CI passed.

### Potential Future Issues
- The CI runner has Xcode 15.4 (not 16.x like local). If C++ compiler errors occur,
  check Xcode version compatibility.
- `python` command may not exist on CI runner (only `python3`). The build.sh script
  uses `python` for CMake detection. If this fails, may need a symlink or to patch
  CMakeLists.txt to use `python3`.

## Commands
```bash
# macOS prereqs
brew install openssl cmake unixodbc
# Rust toolchain (for building mssql_py_core from source)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Build mssql_py_core from source targeting macOS 14
git clone https://github.com/microsoft/mssql-rs.git /tmp/mssql-rs
cd /tmp/mssql-rs
rustup target add x86_64-apple-darwin  # needed because rust-toolchain.toml pins 1.90
cd mssql-py-core
MACOSX_DEPLOYMENT_TARGET=14.0 maturin build --release --target universal2-apple-darwin --auditwheel=skip
cd -
pip install /tmp/mssql-rs/mssql-py-core/target/wheels/mssql_py_core-*.whl \
  --target /tmp/mssql_py_core_extract --no-deps
mkdir -p mssql_py_core
cp -r /tmp/mssql_py_core_extract/mssql_py_core/ mssql_py_core/

# Patch bundled ODBC dylibs to target macOS 14.0
for f in mssql_python/libs/macos/arm64/lib/*.dylib mssql_python/libs/macos/x86_64/lib/*.dylib; do
    tmpf=$(mktemp) && vtool -set-build-version macos 14.0 15.0 -output "$tmpf" "$f" && mv "$tmpf" "$f"
    codesign --force --sign - "$f"
done

# Build C++ extension
cd mssql_python/pybind && ./build.sh

# Package wheel
python setup.py bdist_wheel
```

## CI/CD (GitHub Actions)
- `.github/workflows/build-macos-wheel.yml` — builds on `macos-14` runner (M1, Sonoma)
  with pip cache + Swatinem/rust-cache, currently Python 3.13 only (testing)
- `.github/workflows/sync-upstream.yml` — weekly sync from `microsoft/mssql-python` main

## Directory Structure (key paths)
- `mssql_python/pybind/` — C++ source, CMakeLists.txt, build.sh
- `mssql_python/libs/macos/` — bundled ODBC driver dylibs (arm64 + x86_64)
- `mssql_python/libs/odbc_include/` — bundled ODBC headers (sql.h, sqlext.h, etc.)
- `eng/scripts/` — build helpers (install-mssql-py-core.sh, extract_wheel.py)
- `eng/versions/mssql-py-core.version` — pins mssql_py_core version (for reference)
- `setup.py` — wheel packaging + platform tag logic
- `tests/` — pytest suite (requires SQL Server connection)

## Upstream Remote
- Source: `https://github.com/microsoft/mssql-python`
- Sync: weekly via `sync-upstream.yml` workflow
- Upstream uses Azure DevOps (OneBranchPipelines/) for their CI — we use GitHub Actions

## Known Risk
The bundled ODBC dylibs ship with `minos 15.0` and are patched to `minos 14.0` using
`vtool`. This works as long as they don't use macOS 15-only APIs. The `mssql_py_core`
Rust extension is now built from source targeting macOS 14.0, so it has no compatibility
risk. If dylib runtime crashes occur on macOS 14, Microsoft would need to provide ODBC
driver binaries targeting macOS 14.

## Lint / Typecheck
- Upstream uses black, flake8, pylint (see pyproject.toml, .flake8)
- Python >=3.10 required
- Run: `pip install black flake8 pylint && black --check . && flake8`
