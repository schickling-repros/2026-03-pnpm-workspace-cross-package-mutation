# pnpm — Workspace install rewrites node_modules in other packages

When multiple packages have separate `pnpm-workspace.yaml` files listing overlapping workspace members, `pnpm install` in one package rewrites `node_modules/` symlinks in the member packages. This creates multiple physical copies of the same dependency at different `.pnpm` store paths, which causes TypeScript TS2742 "inferred type cannot be named" errors.

## Reproduction

```bash
pnpm install  # not needed if lockfiles already present
bash repro.sh
```

## Setup

```
packages/
├── lib-a/              # Standalone workspace, exports effect types
│   ├── package.json    # effect as devDep + peerDep
│   ├── pnpm-workspace.yaml  # just "."
│   └── src/mod.ts
└── lib-b/              # Workspace that includes lib-a as member
    ├── package.json    # effect as devDep, lib-a as workspace:*
    ├── pnpm-workspace.yaml  # "." + "../lib-a"
    └── src/mod.ts      # imports from lib-a (forces type inference)
```

## Expected

`pnpm install` in lib-a should only modify `packages/lib-a/node_modules/`. lib-b's workspace install already set up lib-a's symlinks correctly — lib-a's standalone install should not overwrite them.

## Actual

1. `pnpm install` in lib-b (workspace) sets `lib-a/node_modules/effect` → `lib-b/node_modules/.pnpm/effect@3.19.15/...` (shared store, correct)
2. `pnpm install` in lib-a (standalone) overwrites `lib-a/node_modules/effect` → `lib-a/node_modules/.pnpm/effect@3.19.15/...` (separate store)
3. TypeScript in lib-b sees effect types from lib-a going through a different physical path → **TS2742**

```
src/mod.ts(5,14): error TS2742: The inferred type of 'service' cannot be named
without a reference to 'lib-a/node_modules/.pnpm/effect@3.19.15/node_modules/effect/Effect'.
This is likely not portable. A type annotation is necessary.
```

## Impact

In monorepos with per-package lockfiles (each package has its own `pnpm-workspace.yaml` and `pnpm-lock.yaml`), install order determines which symlinks survive. Packages listed as workspace members in multiple workspaces get their `node_modules/` rewritten by each install — the last writer wins.

This means:
- **CI flakes**: parallel installs can corrupt each other's `node_modules`
- **TypeScript errors**: different `.pnpm` store paths for the same version cause TS2742
- **Sequential install requirement**: must serialize all installs to avoid races

## Versions

- pnpm: 10.28.0
- TypeScript: 5.8.3
- effect: 3.19.15
- Node: v24.2.0
- OS: Linux 6.12.69

## Related Issue

<!-- TBD -->
