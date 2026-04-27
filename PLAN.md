# Plan: Slim Build Repo

## Current state (fork)
```
254 MB repo = fork of microsoft/mssql-python + CI patches
```

## Target state (slim build repo)
```
~5 KB repo = just workflow + patches + scripts + AI dev files
```

## What we need from upstream `microsoft/mssql-python`

| Item | How we get it |
|---|---|
| All Python source (`mssql_python/`, `setup.py`, `eng/`) | `git clone --depth 1` in CI |
| Bundled ODBC dylibs (5 MB) | Come with the clone, live in `mssql_python/libs/macos/` |
| C++ source (`mssql_python/pybind/`) | Comes with the clone |

## What we build from `microsoft/mssql-rs`

| Item | How we get it |
|---|---|
| `mssql_py_core` Rust extension | `git clone --depth 1` + `maturin build` in CI |

## What our repo contains (the "patches")

1. **`patches/setup.py.patch`** — 2 changes:
   - `macosx_15_0_universal2` → `macosx_14_0_universal2`
   - Add `self.plat_name_supplied = True`

2. **`patches/cmake.patch`** — 1 change:
   - Add `CMAKE_OSX_DEPLOYMENT_TARGET=14.0` in the `if(APPLE)` block

3. **`scripts/patch-dylibs.sh`** — vtool + codesign the dylibs

4. **`scripts/build-mssql-py-core.sh`** — clone mssql-rs, build with maturin, extract into place

5. **`.github/workflows/build-macos-wheel.yml`** — the CI workflow that orchestrates everything

6. **`AGENTS.md`** + other AI dev files (`.claude/`, etc.)

## Workflow outline

```yaml
jobs:
  build:
    runs-on: macos-14
    strategy:
      matrix:
        python-version: ["3.10", "3.11", "3.12", "3.13", "3.14"]
    steps:
      - uses: actions/checkout@v4          # our slim repo

      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}

      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: x86_64-apple-darwin

      - name: Clone upstream mssql-python
        run: git clone --depth 1 https://github.com/microsoft/mssql-python.git /tmp/mssql-python

      - name: Apply macOS 14 patches
        run: |
          patch -d /tmp/mssql-python -p1 < patches/setup.py.patch
          patch -d /tmp/mssql-python -p1 < patches/cmake.patch

      - name: Install system dependencies
        run: brew install openssl unixodbc

      - name: Install Python dependencies
        run: pip install setuptools wheel cmake pybind11 maturin
        working-directory: /tmp/mssql-python

      - name: Build mssql_py_core from source
        run: scripts/build-mssql-py-core.sh /tmp/mssql-python

      - name: Patch ODBC dylib deployment targets
        run: scripts/patch-dylibs.sh /tmp/mssql-python

      - name: Build C++ extension
        run: |
          cd mssql_python/pybind
          chmod +x build.sh configure_dylibs.sh
          ./build.sh
        working-directory: /tmp/mssql-python

      - name: Build wheel
        run: python setup.py bdist_wheel
        working-directory: /tmp/mssql-python

      - name: Upload wheel artifact
        uses: actions/upload-artifact@v4
        with:
          name: whl-cp${{ matrix.python-version }}
          path: /tmp/mssql-python/dist/*.whl
```

## Migration steps

1. Generate the two patch files from our current diffs
2. Extract the dylib patching + mssql-py-core build into standalone scripts
3. Rewrite the workflow to clone upstream + apply patches
4. Test on CI (Python 3.13 only first)
5. If green: hard-reset `main` to only contain the slim files
6. Restore full Python matrix

## What we lose
- The `sync-upstream.yml` workflow (no longer needed — we always build against latest upstream `main`)
- Ability to test locally without cloning upstream

## What we gain
- No upstream merge conflicts, ever
- Repo goes from 254 MB to ~5 KB
- Always builds against latest upstream (could be a pro or con)

## Risk
- If upstream renames files we patch, the patches break silently. Mitigation: CI will fail on `patch` and we'll know immediately.
