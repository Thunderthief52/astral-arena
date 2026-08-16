# Astral Arena Adventure playtest

## Build under test

- Version: `0.3.2-alpha.3`
- Adventure UUID: `29c48c80-8777-f7b5-6bb8-376c1c5d8db6`
- Character flow: BG3 system character creator → `AA_Arena_Main`
- PAK: `dist\AstralArena-0.3.2-alpha.3.pak`

This candidate fixes split-screen XP delivery so each independently owned local avatar reaches the same target, while retaining the safe fresh New Game handoff and shipped-asset visual pass. It can also repair a real-character split-screen save left at mixed levels by the previous build. Astral Staging has a safe stone circle and landmark arches; Astral Flats uses open rocks and broken menhirs; Crescent Ruin uses curved stonework, rubble, and a Selûnite statue; and Echelon Steps uses an inward-shifted staggered high-ground edge.

## Install

1. Close Baldur's Gate 3.
2. Install Norbyte's BG3 Script Extender, API version 30 or newer.
3. Open PowerShell in the repository root and run:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\scripts\Install-Pak.ps1 -PakPath ".\dist\AstralArena-0.3.2-alpha.3.pak"
   ```

4. Confirm this file exists:

   ```text
   %LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods\AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6.pak
   ```

5. Launch BG3, open **Mod Manager**, and enable **Astral Arena Adventure**.
6. Disable older Astral Arena development copies. Only one mod with the Adventure UUID above may be active.
7. For online co-op, repeat these steps on every PC with the same BG3, Script Extender, PAK, and load-order versions. Split-screen requires one installation.

## Discard placeholder-party saves

Do not continue a save containing four naked, classless, immobile characters at one HP. Those entities are BG3's temporary system character-creation placeholders, not recoverable player builds. Delete or ignore that playtest save and begin a fresh New Game with `0.3.2-alpha.3` enabled. A save containing your two real custom split-screen characters, one at level 5 and one at level 1, is recoverable: install this build, reload it, and finish the newly offered level-ups on the lower character.

## Start a clean Adventure

1. Choose **New Game**. If BG3 presents an Adventure selector, choose **Astral Arena Adventure**.
2. Create one character for solo, join the ordinary online lobby before finalizing characters for co-op, or connect the second controller before completing split-screen character creation.
3. Finish the supported BG3 system character creator normally. This system scene is expected; it is not a campaign location. Do not use Honour Mode for this alpha.
4. Confirm the finished custom party transfers into `AA_Arena_Main`, not a Nautiloid or Act 1 campaign location. A naked character-creation dummy must not remain active.
5. Make a named manual save such as `AA 0.3.2-alpha.3 BEFORE AUTO START`.
6. After character creation completes, confirm Astral Arena automatically awards the vanilla level-5 XP threshold and displays a notification. No console command is required.
7. Complete every ordinary BG3 level-up through level 5. In co-op or split-screen, both players should receive XP and each player completes their own choices.
8. Confirm the runtime silently validates the party, enemy fixtures, and reward catalog, then moves the whole party to Astral Flats and begins the three-second countdown.

If automatic onboarding pauses, `!aa_ai_status` and `!aa_ai_doctor` remain available as diagnostics. `!aa_ai_bootstrap`, `!aa_ai_start`, and `!aa_ai_continue` are recovery commands, not normal play steps.

## Verify the three bouts

| Bout | Party level | Expected site | Opponent | Reward target |
| --- | ---: | --- | --- | ---: |
| 1 | 5 | Astral Flats | Astral Vanguard | 8 |
| 2 | 8 | Crescent Ruin | Astral Bastion | 10 |
| 3 | 10 | Echelon Steps | Astral Judicators | 12 |

For each bout:

1. Confirm the party moves together from staging to the named site during setup and every character stands on solid terrain.
2. Confirm the site's surrounding arches, pillars, rocks, rubble, vegetation, or steps render normally instead of as missing or black placeholder geometry.
3. Confirm four temporary enemies appear ahead of the party on valid ground and the three-second countdown completes.
4. Fight normally. Defeated characters should stop at one HP.
5. After victory, confirm temporary enemies disappear and every player returns to staging with health/resources restored.
6. Choose one of the six rare candidates and its recipient:

   ```text
   !aa_ai_pick <choice 1-6> <party-member 1-4>
   ```

7. Confirm the recipient receives the chosen item plus the automatic `RewardMedium` bundle.
8. Complete native level-ups to the next target; the next bout starts automatically when every player is ready.

After the third reward, finish leveling to 12. The runtime automatically completes the run; expected console output is `Astral Arena champion complete at level 12.`

## Mode-specific checks

- **Solo:** one player-created avatar can complete automatic onboarding and all three bouts.
- **Ordinary co-op:** every connected player's avatar moves to each site, remains controllable by its owner, receives party XP, and can be selected as a reward recipient.
- **Split-screen:** both local avatars move together, remain controllable by their controllers, and return to staging after cleanup. Test with one avatar per controller before adding companions.
- **Party size:** test one character first, then two to four. The runtime rejects more than four active party members.

## Recovery and stop conditions

Use `!aa_ai_abort` if a bout is stuck. It should leave combat, delete temporary enemies, restore the party, and return everyone to staging. Use `!aa_ai_reset` only to reset session state; it does not remove XP or items.

Stop and reload `AA 0.3 BEFORE BOOTSTRAP` if any character dies permanently, spawns outside valid terrain, remains in combat or hostile after cleanup, fails to return to staging, loses controller ownership, receives duplicate loot, or triggers repeating Lua errors. Do not save during an active bout.

## Report

Include the BG3, Script Extender, and PAK versions; solo/co-op/split-screen mode; party size and builds; active load order; all `[Astral Arena]` console lines; the failed bout/site; whether `!aa_ai_abort` recovered; and whether reloading the pre-bootstrap save fully restored the game.
