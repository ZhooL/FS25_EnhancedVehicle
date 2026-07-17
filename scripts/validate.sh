#!/usr/bin/env bash
set -euo pipefail

repository=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repository"

if [[ -n "${LUAC:-}" ]]; then
  lua_compiler=$LUAC
elif command -v luac5.1 >/dev/null 2>&1; then
  lua_compiler=luac5.1
elif command -v luac >/dev/null 2>&1; then
  lua_compiler=luac
else
  echo "validation: Lua compiler not found; install Lua 5.1 or set LUAC" >&2
  exit 1
fi

while IFS= read -r lua_file; do
  "$lua_compiler" -p "$lua_file"
done < <(python3 tests/check_release.py --list-lua)
echo "Validated runtime Lua syntax with $lua_compiler"

if [[ -n "${LUA:-}" ]]; then
  lua_runtime=$LUA
elif command -v lua5.1 >/dev/null 2>&1; then
  lua_runtime=lua5.1
elif command -v lua >/dev/null 2>&1; then
  lua_runtime=lua
else
  echo "validation: Lua runtime not found; install Lua 5.1 or set LUA" >&2
  exit 1
fi

"$lua_compiler" -p tests/check_runtime.lua
"$lua_runtime" tests/check_runtime.lua
"$lua_compiler" -p tests/check_client_runtime.lua
"$lua_runtime" tests/check_client_runtime.lua

python3 tests/check_release.py
python3 tests/check_contracts.py
python3 tests/check_engine_contract.py
python3 -m unittest tests.test_integration_tools tests.test_release_archive
python3 scripts/package.py
python3 tests/check_release.py --archive build/FS25_EnhancedVehicle.zip

comparison_archive=$(mktemp "${TMPDIR:-/tmp}/FS25_EnhancedVehicle.XXXXXXXX.zip")
trap 'rm -f "$comparison_archive"' EXIT
python3 scripts/package.py "$comparison_archive" >/dev/null
if ! cmp --silent build/FS25_EnhancedVehicle.zip "$comparison_archive"; then
  echo "validation: repeated packaging produced different archive bytes" >&2
  exit 1
fi
echo "Validated deterministic packaging"
