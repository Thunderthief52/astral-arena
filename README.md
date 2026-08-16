# Astral Arena

Astral Arena is an experimental Baldur's Gate 3 arena Adventure for Windows. Version `0.3.2-alpha.3` fixes split-screen XP onboarding and automatically repairs real-character parties left at mixed levels, while retaining the safe character-creation handoff, base-game-asset visual pass, and cooperative AI progression. Its longer-term goal is an eight-entrant 5 → 8 → 10 → 12 live bracket plus a separate asynchronous level-pool mode built from player-authored parties.

> **Alpha safety note:** use a separate manual save, remove story NPCs from the area, and do not save during an active match. The mod restores combat relationships and characters after a bout, but this is the first engine playtest build.

## What is playable now

- Two connected BG3 users, each controlling one to four same-level party members.
- Split-screen 1v1 fallback using the two local player-avatar entities when BG3 reports only one ordinary ownership group.
- Automatic team discovery from BG3's multiplayer character assignments.
- Temporary cross-team hostility and automatic combat entry.
- Nonlethal defeat at 1 HP using temporary immortality.
- Automatic win/draw detection, relationship cleanup, healing, and resource restoration.
- Manual forfeit and emergency abort commands.
- Three-second start countdown and automatic team rescan for rematches.
- A deterministic eight-entrant tournament simulator and a tested 1–12 asynchronous run model.
- A tested deterministic reward engine for level-banded automatic bundles and one-of-six equipment offers.
- An experimental player-party-versus-AI run with fights at levels 5, 8, and 10, native progression to 8, 10, and 12, and post-win loot.
- Automatic post-character-creation onboarding that grants the vanilla level-5 XP threshold, waits for every player-authored level-up choice, validates fixtures and rewards internally, and starts each ready bout.
- A Toolkit-authored Adventure module that starts in the isolated `AA_Arena_Main` level rather than a vanilla campaign location.
- A decorated safe staging area plus three visually distinct runtime-selected combat sites: Astral Flats, Crescent Ruin, and Echelon Steps.
- Twelve deterministic-random enemy formations, with the first three bouts bound to those sites and cleanup returning the party to staging.

The level now uses shipped BG3 stonework, ruins, rocks, vegetation, cover, elevation, and colored accent lighting. Final terrain polish, graphical bracket/reward UI, player-authored AI ghosts, Eddard matchmaking coordinator, and public rankings are **not** in this alpha.

## Requirements

- Baldur's Gate 3 on Windows.
- [Norbyte's BG3 Script Extender](https://github.com/Norbyte/bg3se), API version 30 or newer.
- BG3's in-game Mod Manager, or [BG3 Mod Manager](https://github.com/LaughingLeader/BG3ModManager), to activate the PAK.
- One to four fresh player-created characters for the Adventure progression test.
- Two online players or two local split-screen players for PvP sparring.
- Online co-op only: the same Astral Arena build and compatible mod load order on both PCs.

## Install the Adventure PAK

The Toolkit build is `dist\AstralArena-0.3.2-alpha.3.pak`.

1. Close Baldur's Gate 3.
2. Install Norbyte's Script Extender if it is not already present.
3. From the repository root, install the PAK:

   ```powershell
   .\scripts\Install-Pak.ps1 -PakPath ".\dist\AstralArena-0.3.2-alpha.3.pak"
   ```

   Manual alternative: copy the PAK to:

   ```text
   %LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods\AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6.pak
   ```

4. Launch BG3 and open **Mod Manager**.
5. Enable **Astral Arena Adventure**. Disable older Astral Arena development copies so only one module with UUID `29c48c80-8777-f7b5-6bb8-376c1c5d8db6` is active.
6. Choose **New Game**, select **Astral Arena Adventure** if BG3 displays an Adventure choice, and create the player characters.
7. For ordinary online co-op, install the identical PAK and Script Extender version on every PC. Split-screen needs one installation.

The installer backs up a previous canonical Adventure PAK under `%LOCALAPPDATA%\AstralArena\PakBackups`. Saves containing the temporary 1-HP character-creation dummies remain invalid and should be discarded. A save containing the two real custom split-screen characters at mixed levels can be reloaded with `0.3.2-alpha.3`; the lower-level avatar receives its missing XP and the first bout begins after both players finish leveling to 5. Follow the exact new-game, solo, co-op, and split-screen checklist in [docs/ADVENTURE_PLAYTEST.md](docs/ADVENTURE_PLAYTEST.md).

## Run the first match

1. Both players load the same multiplayer save.
2. Make a new manual save specifically for the playtest.
3. Move to a wide, flat area with no neutral or story NPCs nearby. Ungroup summons and dismiss temporary followers.
4. Open **Escape → Multiplayer/Session** and assign each fighting character to the correct player. Begin with one character per player; expand to 2v2 or 4v4 after that succeeds.
5. In the host's Script Extender console, enter:

   ```text
   !aa_doctor
   ```

   It should resolve either two assigned users or the two split-screen player avatars, with matching character levels.
6. Start the match:

   ```text
   !aa_spar
   ```

7. Fight normally. A character is eliminated when it reaches 1 HP. When every member of one side is eliminated, Astral Arena announces the winner and restores both teams.
8. If the match becomes stuck, the host should enter:

   ```text
   !aa_abort
   ```

9. After cleanup, verify that both teams can move, target normally, and are no longer hostile. If anything remains wrong, reload the manual save and include that result in the report.

## Run a split-screen match

1. Install and activate Astral Arena once on the Windows PC.
2. Connect two controllers and enter BG3 split-screen before loading the test save.
3. Use one same-level player avatar per controller for the first test. Companions may remain in the party but become spectators when the fallback is active.
4. Make a disposable manual save and move both avatars to a clear area.
5. Alt-tab to the host Script Extender console and enter `!aa_doctor`.
6. Confirm it prints `READY via split-screen fallback` and names the correct two avatars.
7. Enter `!aa_spar`, return to the game during the three-second countdown, and fight normally.

If BG3 exposes the two controllers as normal distinct users, the doctor may instead print `READY via multiplayer assignments`; that route is also valid. Astral Arena never guesses companion ownership in fallback mode, so the fallback is deliberately 1v1 for this alpha.

For the PvP test matrix, expected results, logs, and bug-report checklist, read [PLAYTEST.md](PLAYTEST.md).

## Run the AI progression playtest

Start a disposable Astral Arena Adventure new game with one to four player-created characters. The Adventure automatically grants the level-5 XP threshold after character creation, waits until everyone finishes native level-up choices, validates the encounter, and moves the party to Astral Flats. After each victory, use `!aa_ai_pick <choice 1-6> <party-member number>` for this alpha's reward choice; later bouts start automatically once everyone finishes leveling. The three bouts use Astral Flats, Crescent Ruin, and Echelon Steps, returning the party to staging after cleanup.

This mode awards real loot and XP. Read [docs/AI_PLAYTEST.md](docs/AI_PLAYTEST.md) before starting; `!aa_ai_reset` does not undo inventory or experience changes.

## Console commands

| Command | Purpose |
| --- | --- |
| `!aa_help` | List commands and the installed alpha version. |
| `!aa_version` | Show Astral Arena and Script Extender versions. |
| `!aa_doctor` | Check connected users, character ownership, levels, and GUIDs. |
| `!aa_scan` | List the characters assigned to each multiplayer user. |
| `!aa_spar` | Start a match between the two detected users. |
| `!aa_rematch` | Rescan current ownership/avatar state and start another match. |
| `!aa_spar_status` | Show the current or most recent match result. |
| `!aa_forfeit left` | Make the left/first scanned user concede. |
| `!aa_forfeit right` | Make the right/second scanned user concede. |
| `!aa_abort` | End an active match and restore both teams. |
| `!aa_demo` | Run the deterministic eight-entrant bracket setup. |
| `!aa_state` | Print the simulated bracket state. |
| `!aa_ai_doctor` | Optional diagnostic: validate the active party, AI fixtures, and reward templates without mutation. |
| `!aa_ai_bootstrap` | Recovery command: manually trigger the otherwise automatic level-1 bootstrap. |
| `!aa_ai_start` | Recovery command: manually start the level-5 run if automatic onboarding pauses. |
| `!aa_ai_pick 1 1` | Take reward choice 1 on party member 1 and award next-tier XP. |
| `!aa_ai_continue` | Recovery command: manually start a ready next tier. |
| `!aa_ai_status` | Show AI run state. |
| `!aa_ai_abort` | Abort combat, restore players, and delete temporary AI enemies. |
| `!aa_ai_reset` | Reset session state without removing awarded loot or XP. |

## Build and test from source

The deterministic Lua code runs outside BG3 with LuaJIT or Lua 5.1+:

```sh
luajit tests/run.lua
luajit scripts/simulate.lua
./scripts/build-release.sh 0.3.2-alpha.3
```

Windows equivalents:

```powershell
lua tests\run.lua
.\scripts\Build-Pak.ps1 -Version 0.3.2-alpha.3
.\scripts\Build-Release.ps1 -Version 0.3.2-alpha.3
```

`Build-Pak.ps1` combines the checked-in Toolkit level, the current Script Extender runtime, and the Toolkit-generated module artwork into the installable Adventure PAK. Run it after syncing/opening the project in the Toolkit. `Build-Release.ps1` then includes that PAK and the playtest documentation in the generated archive under `dist/`.

## Project documentation

- [Adventure installation and playtest](docs/ADVENTURE_PLAYTEST.md)
- [Legacy PvP playtest protocol](PLAYTEST.md)
- [AI progression playtest](docs/AI_PLAYTEST.md)
- [Dedicated new-game arena design](docs/NEW_GAME_ARENA.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Milestones](docs/MILESTONES.md)
- [Release-sized next steps](docs/NEXT_STEPS.md)
- [Player-authored level-pool mode](docs/LEVEL_POOL_VARIANT.md)
- [Arena rewards and item-safety boundary](docs/REWARDS.md)
- [Eddard coordinator boundary](docs/EDDARD_COORDINATOR.md)
- [Contributing](CONTRIBUTING.md)

## Compatibility and provenance

Astral Arena currently targets vanilla BG3 characters. Mods that change party limits can be used to assemble larger teams, but the first report should use 1v1 on a minimal load order. Custom classes, subclasses, spells, items, and difficulty overhauls are not validated yet.

Trials of Tav, Brawl, PvP Combat, Versus Mode, and other BG3 arena projects are architectural references. Their code and assets are not copied into this repository. Astral Arena is an independent MIT-licensed project and is not affiliated with or endorsed by Larian Studios.
