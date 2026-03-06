#!/usr/bin/env bash
set -euo pipefail

# Minimal reproduction: pnpm install in one package rewrites node_modules
# symlinks in another package when they share overlapping workspace members.
#
# Setup:
#   lib-a: standalone workspace, exports effect types (Schema, Effect)
#   lib-b: workspace that includes lib-a as a member, re-exports from lib-a
#
# Both have effect as a dependency. When lib-a reinstalls standalone AFTER
# lib-b's workspace install, it creates a separate .pnpm store copy —
# causing TypeScript TS2742 "inferred type cannot be named" errors.

cd "$(dirname "$0")"

echo "=== Clean state ==="
rm -rf packages/lib-a/node_modules packages/lib-a/dist
rm -rf packages/lib-b/node_modules packages/lib-b/dist

echo ""
echo "=== Step 1: Install lib-b (workspace includes lib-a) ==="
(cd packages/lib-b && pnpm install --config.confirmModulesPurge=false 2>&1)

echo ""
echo "lib-a/node_modules/effect points to:"
readlink packages/lib-a/node_modules/effect
echo "(physical: $(readlink -f packages/lib-a/node_modules/effect))"

echo ""
echo "lib-b/node_modules/effect points to:"
readlink packages/lib-b/node_modules/effect
echo "(physical: $(readlink -f packages/lib-b/node_modules/effect))"

SAME=$([ "$(readlink -f packages/lib-a/node_modules/effect)" = "$(readlink -f packages/lib-b/node_modules/effect)" ] && echo "YES" || echo "NO")
echo ""
echo "Same physical effect? $SAME"

echo ""
echo "=== Step 2: TypeScript check (should PASS — same effect copy) ==="
(cd packages/lib-b && npx tsc --build --force 2>&1) && echo "PASS" || echo "FAIL"

echo ""
echo "=== Step 3: Reinstall lib-a standalone (simulates install order issue) ==="
(cd packages/lib-a && pnpm install --config.confirmModulesPurge=false 2>&1)

echo ""
echo "lib-a/node_modules/effect NOW points to:"
readlink packages/lib-a/node_modules/effect
echo "(physical: $(readlink -f packages/lib-a/node_modules/effect))"

echo ""
echo "lib-b/node_modules/effect still points to:"
readlink packages/lib-b/node_modules/effect
echo "(physical: $(readlink -f packages/lib-b/node_modules/effect))"

SAME=$([ "$(readlink -f packages/lib-a/node_modules/effect)" = "$(readlink -f packages/lib-b/node_modules/effect)" ] && echo "YES" || echo "NO")
echo ""
echo "Same physical effect? $SAME"

echo ""
echo "=== Step 4: TypeScript check (expected FAIL — different effect copies → TS2742) ==="
rm -rf packages/lib-a/dist packages/lib-b/dist
(cd packages/lib-b && npx tsc --build --force 2>&1) && echo "PASS" || echo "FAIL"
