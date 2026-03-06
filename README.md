# Per-package pnpm workspaces: cross-package node_modules mutation

Minimal reproduction of the cross-package `node_modules` mutation problem that occurs with per-package pnpm workspaces (each package has its own `pnpm-workspace.yaml` and `pnpm-lock.yaml`).

This is expected pnpm behavior — each `pnpm install` correctly manages its own workspace. The problem is that overlapping workspace members get their `node_modules/` rewritten by every workspace that includes them, with the last install winning.

## Reproduction

```bash
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

## What happens

1. `pnpm install` in lib-b (workspace) sets `lib-a/node_modules/effect` → `lib-b/node_modules/.pnpm/effect@3.19.15/...` (shared store)
2. `pnpm install` in lib-a (standalone) overwrites `lib-a/node_modules/effect` → `lib-a/node_modules/.pnpm/effect@3.19.15/...` (separate store)
3. lib-a and lib-b now resolve `effect` to different physical paths despite same version
4. TypeScript emits **TS2742** because it can't name types that reference the foreign `.pnpm` store path

```
src/mod.ts(5,14): error TS2742: The inferred type of 'service' cannot be named
without a reference to 'lib-a/node_modules/.pnpm/effect@3.19.15/node_modules/effect/Effect'.
This is likely not portable. A type annotation is necessary.
```

## Consequences

- **TypeScript errors**: different `.pnpm` store paths for the same version cause TS2742
- **CI flakes**: parallel installs can corrupt each other's `node_modules`
- **Sequential install requirement**: must serialize all installs to avoid races
- **Install order sensitivity**: topological ordering (leaf packages first, workspace roots last) is required as a workaround

## Versions

- pnpm: 10.28.0
- TypeScript: 5.8.3
- effect: 3.19.15

## Related

- [overengineeringstudio/effect-utils#322](https://github.com/overengineeringstudio/effect-utils/issues/322)
