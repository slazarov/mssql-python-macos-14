# Plan: Slim Build Repo

## Status: COMPLETE

Migration from 254 MB fork to ~5 KB slim build repo is done.

## What our repo contains
1. `patches/setup.py.patch` — platform tag + plat_name_supplied
2. `patches/cmake.patch` — CMAKE_OSX_DEPLOYMENT_TARGET=14.0
3. `scripts/patch-dylibs.sh` — vtool + codesign dylibs
4. `scripts/build-mssql-py-core.sh` — clone mssql-rs, build with maturin
5. `.github/workflows/build-macos-wheel.yml` — CI workflow
6. `AGENTS.md` + `PLAN.md`

## What we lost
- `sync-upstream.yml` (no longer needed — always builds against latest upstream main)
- Ability to test locally without cloning upstream
- 254 MB of upstream source code

## What we gained
- No upstream merge conflicts, ever
- Repo is ~5 KB
- Always builds against latest upstream
