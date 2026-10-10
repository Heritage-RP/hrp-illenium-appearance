#!/usr/bin/env sh
# Lua tests (PRODUCTION-SERVER#12): every tests/lua/*_spec.lua in Lua 5.4, in docker (image nickblah/lua:5.4).
# Usage, from anywhere: tests/run.sh   (LUA=lua5.4 tests/run.sh runs them with a local Lua 5.4 instead of docker)
set -eu
cd "$(dirname "$0")/.."

status=0
for spec in tests/lua/*_spec.lua; do
    echo "== $spec"
    if [ -n "${LUA:-}" ]; then
        "$LUA" "$spec" || status=1
    else
        docker run --rm -v "$PWD":/w -w /w nickblah/lua:5.4 lua "$spec" || status=1
    fi
done
exit $status
