# Contributing

Astral Arena is in an engine-validation alpha. The most useful contributions are reproducible playtest reports, Script Extender API corrections, and small changes with deterministic Lua tests.

## Development checks

Run before opening a pull request:

```sh
lua tests/run.lua
lua scripts/simulate.lua
./scripts/build-release.sh test
```

Keep game-independent rules under `AstralArena/Core`. Put `Ext` and `Osi` calls behind server/client adapters. New domain behavior should be testable without launching BG3.

Do not copy code, assets, encounters, maps, characters, or balance tables from other mods without compatible licensing and explicit attribution. Do not commit game assets extracted from Baldur's Gate 3.

## Pull requests

Explain the player-visible change, engine assumptions, cleanup behavior, validation performed, and any mod compatibility impact. Treat changes to faction relationships, character ownership, death, saves, networking, or installer paths as high risk.
