# Astral Arena

Astral Arena is an experimental Baldur's Gate 3 party-versus-party tournament mod for Windows. The current alpha provides a console-driven online or split-screen sparring match that can be played in any clear campaign area. Its longer-term goal is an eight-entrant 5 → 8 → 10 → 12 bracket plus a separate asynchronous level-pool mode built from player-authored parties.

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

The custom arena map, graphical bracket UI, automatic leveling, AI ghost parties, Eddard matchmaking coordinator, and public rankings are **not** in this alpha.

## Requirements

- Baldur's Gate 3 on Windows.
- [Norbyte's BG3 Script Extender](https://github.com/Norbyte/bg3se), API version 30 or newer.
- [BG3 Mod Manager](https://github.com/LaughingLeader/BG3ModManager) for activating the unpacked project.
- Two online players or two local split-screen players for the current sparring mode.
- Online co-op only: the same Astral Arena build and compatible mod load order on both PCs.

## Install a release

1. Download and extract `AstralArena-0.1.1-alpha.1.zip` from the [alpha release page](https://github.com/Thunderthief52/astral-arena/releases/tag/v0.1.1-alpha.1).
2. Open PowerShell in the extracted folder.
3. If PowerShell blocks local scripts, allow them for only this window:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   ```

4. Install the mod. The common Steam path is detected automatically:

   ```powershell
   .\Install-Playtest.ps1
   ```

   For another Steam library or GOG installation, pass the BG3 `Data` folder:

   ```powershell
   .\Install-Playtest.ps1 -Bg3DataPath "D:\SteamLibrary\steamapps\common\Baldurs Gate 3\Data"
   ```

5. Open BG3 Mod Manager and refresh. Move **Astral Arena** to the active/left list, save the order, and export it to the game.
6. Install Script Extender through BG3 Mod Manager's **Tools → Download & Extract the Script Extender** command if it is not already installed.
7. Enable the development console without discarding existing Script Extender settings:

   ```powershell
   .\Enable-SE-Console.ps1 -Bg3DataPath "D:\SteamLibrary\steamapps\common\Baldurs Gate 3\Data"
   ```

8. For online co-op, repeat installation and load-order activation on the second PC. Split-screen requires only the one installation.

The installer backs up an existing Astral Arena copy under `%LOCALAPPDATA%\AstralArena\Backups` before replacing it.

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

For the full test matrix, expected results, logs, and bug-report checklist, read [PLAYTEST.md](PLAYTEST.md).

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

## Build and test from source

The deterministic Lua code runs outside BG3 with LuaJIT or Lua 5.1+:

```sh
luajit tests/run.lua
luajit scripts/simulate.lua
./scripts/build-release.sh 0.1.1-alpha.1
```

Windows equivalents:

```powershell
lua tests\run.lua
.\scripts\Build-Release.ps1 -Version 0.1.1-alpha.1
```

The generated playtest archive is written under `dist/`.

## Project documentation

- [Playtest protocol](PLAYTEST.md)
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
