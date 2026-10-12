# mssql-python-macos-14

macOS 14 (Sonoma) compatible wheels for
[microsoft/mssql-python](https://github.com/microsoft/mssql-python).

The official upstream macOS wheels are tagged `macosx_15_0_universal2`, which means
macOS 15 Sequoia or newer. This repo rebuilds the same upstream release with a
`macosx_14_0_universal2` wheel tag and a macOS 14 deployment target.

## Install

Supported Python versions are `3.10`, `3.11`, `3.12`, `3.13`, and `3.14`.

Since upstream `v1.15.0`, the ODBC driver ships as a separate `mssql-python-odbc`
package that `mssql-python` depends on. Its PyPI wheel is macOS 15+ only, so each
release here also includes a `mssql_python_odbc-*-py3-none-macosx_14_0_universal2.whl`.
Install it in the same `pip` command as the `mssql_python` wheel. The commands below
handle both layouts.

Install the latest versioned macOS 14 release for your current Python:

```bash
RELEASE_TAG="$(
  curl -fsSL https://api.github.com/repos/slazarov/mssql-python-macos-14/releases \
    | python3 -c 'import json, sys
releases = json.load(sys.stdin)
tags = [
    release["tag_name"]
    for release in releases
    if release["tag_name"].startswith("v") and release["tag_name"].endswith("-macos14")
]
if not tags:
    raise SystemExit("No versioned macOS 14 releases found")
print(tags[0])'
)"
VERSION="${RELEASE_TAG#v}"
VERSION="${VERSION%-macos14}"
PY_TAG="cp$(python3 -c 'import sys; print(f"{sys.version_info.major}{sys.version_info.minor}")')"

python3 -m pip install $(
  curl -fsSL "https://api.github.com/repos/slazarov/mssql-python-macos-14/releases/tags/${RELEASE_TAG}" \
    | python3 -c 'import json, sys
py_tag = sys.argv[1]
for asset in json.load(sys.stdin)["assets"]:
    name = asset["name"]
    if name.startswith("mssql_python_odbc-") or f"-{py_tag}-{py_tag}-" in name:
        print(asset["browser_download_url"])' "$PY_TAG"
)
```

Install a specific `mssql-python` version:

```bash
VERSION=1.8.0
PYTHON=3.13
PY_TAG="cp${PYTHON/./}"

python${PYTHON} -m pip install $(
  curl -fsSL "https://api.github.com/repos/slazarov/mssql-python-macos-14/releases/tags/v${VERSION}-macos14" \
    | python3 -c 'import json, sys
py_tag = sys.argv[1]
for asset in json.load(sys.stdin)["assets"]:
    name = asset["name"]
    if name.startswith("mssql_python_odbc-") or f"-{py_tag}-{py_tag}-" in name:
        print(asset["browser_download_url"])' "$PY_TAG"
)
```

Change `VERSION` to the upstream version you want and `PYTHON` to the interpreter
you are installing into. Available versioned releases are listed on the
[Releases page](../../releases).

List available versioned releases from the terminal:

```bash
curl -fsSL https://api.github.com/repos/slazarov/mssql-python-macos-14/releases \
  | python3 -c 'import json, sys
for release in json.load(sys.stdin):
    tag = release["tag_name"]
    if tag.startswith("v") and tag.endswith("-macos14"):
        print(tag)'
```

## Releases

Release tags use this format:

```text
v<upstream-version>-macos14
```

For example, upstream `mssql-python` `v1.8.0` is published here as
`v1.8.0-macos14`.

The workflow:

- runs once per day on a schedule
- can be run manually from GitHub Actions
- does not run on ordinary pushes
- builds only when the latest upstream release SHA is missing here or the existing
  release is incomplete
- publishes wheels for Python `3.10` through `3.14`, plus the `mssql-python-odbc`
  driver wheel for upstream `v1.15.0` and newer

Manual rebuilds are available from GitHub Actions. By default a manual run skips an
existing complete release; set `force_rebuild=true` to rebuild and replace the assets
for the current upstream release.

## What Gets Patched

| File | Change |
|---|---|
| `patches/setup.py.patch` | Wheel platform tag `macosx_15_0_universal2` to `macosx_14_0_universal2`, plus `plat_name_supplied = True` |
| `patches/cmake.patch` | Sets `CMAKE_OSX_DEPLOYMENT_TARGET=14.0` |
| `scripts/patch-dylibs.sh` | Rewrites bundled ODBC dylib deployment targets to macOS 14.0 with `vtool`, then codesigns them (`mssql_python_odbc/libs` since `v1.15.0`, `mssql_python/libs` before) |
| `scripts/build-mssql-py-core.sh` | Builds `mssql_py_core` (dist name `mssql-python-rs`) from `microsoft/mssql-rs` with `MACOSX_DEPLOYMENT_TARGET=14.0` |
| `setup_odbc.py` (env only) | Built with `ODBC_TARGET_PLATFORM_TAG=macosx_14_0_universal2` to produce the macOS 14 `mssql-python-odbc` wheel |

No upstream source code is stored in this repo. The workflow clones the selected
upstream `mssql-python` release tag during the build.

## Local Build

Build the latest upstream release locally:

```bash
UPSTREAM_TAG="$(
  curl -fsSL https://api.github.com/repos/microsoft/mssql-python/releases/latest \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])'
)"
```

Or build a specific upstream version:

```bash
UPSTREAM_TAG=v1.8.0
```

Then run:

```bash
git clone --depth 1 --branch "$UPSTREAM_TAG" https://github.com/microsoft/mssql-python.git /tmp/mssql-python
patch -d /tmp/mssql-python -p1 < patches/setup.py.patch
patch -d /tmp/mssql-python -p1 < patches/cmake.patch

brew install unixodbc
python3 -m pip install --upgrade pip
python3 -m pip install setuptools wheel cmake pybind11 maturin

scripts/build-mssql-py-core.sh /tmp/mssql-python
scripts/patch-dylibs.sh /tmp/mssql-python

cd /tmp/mssql-python/mssql_python/pybind
chmod +x build.sh configure_dylibs.sh
./build.sh

cd /tmp/mssql-python
python3 setup.py bdist_wheel

# v1.15.0+ only: build the macOS 14 ODBC driver wheel
ODBC_TARGET_PLATFORM_TAG=macosx_14_0_universal2 ODBC_TARGET_ARCH=universal2 \
  python3 setup_odbc.py bdist_wheel --dist-dir dist-odbc
```

The wheel is written to `/tmp/mssql-python/dist/` (and the ODBC wheel to
`/tmp/mssql-python/dist-odbc/`).

## Risk

- If upstream changes files we patch, the build fails at the patch step.
- Bundled ODBC dylibs are still Microsoft binaries; this repo only rewrites their
  deployment target metadata.
- If a patched dylib crashes on macOS 14, Microsoft needs to provide macOS 14
  compatible binaries.
