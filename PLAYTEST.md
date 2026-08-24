# Astral Arena alpha playtest protocol

## Purpose of this build

Version `0.1.1-alpha.1` tests whether two online users or two local split-screen player avatars can become opposing teams, finish a nonlethal fight, and return safely to the campaign state.

This build is ready for that focused test. It is not yet the full eight-player tournament.

## Before launching

Record the following for both PCs in online play, or for the one PC in split-screen:

- BG3 game version shown on the main menu.
- Astral Arena version from `!aa_version`.
- Script Extender API version from `!aa_version`.
- Mod Manager version.
- Complete active load order.
- Whether DirectX 11 or Vulkan is used.

Online players should have matching BG3 versions, Astral Arena files, and load orders. Split-screen needs only one installation. Disable unrelated gameplay mods for the first run.

## Safety setup

1. Load a campaign where both players can join normally.
2. Create a new named manual save such as `BEFORE ASTRAL ARENA TEST`.
3. Do not use Honour Mode or an irreplaceable single-save campaign.
4. Move to a flat, open location without neutral, allied, or story NPCs.
5. Dismiss summons and temporary followers. Do not begin while another combat or turn-based mode is active.
6. Do not save while Astral Arena reports an active match.

The mod gives fighters BG3's native death-save passive, treats zero HP as downed, and restores the party after the bout. Chasms, scripted deaths, transformations, domination, and modded instant-kill effects remain unsafe in this alpha.

## Test A — installation and discovery

1. Launch the game through BG3 Mod Manager.
2. Confirm the Script Extender console prints:

   ```text
   [Astral Arena] Server controller registered. Use !aa_help for playtest commands.
   ```

3. Enter `!aa_version` and save the output.
4. Enter `!aa_doctor`.

Expected:

- No red Script Extender error appears.
- Online: the doctor resolves exactly two assigned user IDs.
- Split-screen: the doctor either resolves two assigned users or prints `READY via split-screen fallback` with exactly two player avatars.
- Every intended fighter or fallback avatar appears on the correct side.
- Every listed fighter has the same level.

If online play finds one user and fewer than two avatars, reassign a character to the guest using the game's Multiplayer/Session panel. If it finds more than two users, move extra characters to one of the two fighting users or remove them from the party.

## Test A2 — split-screen discovery

1. Connect two controllers and start split-screen before loading the disposable test save.
2. Use one same-level player avatar for each controller.
3. Enter `!aa_doctor` in the Script Extender console.

Expected:

- Either ordinary ownership resolves two users, or the doctor prints `READY via split-screen fallback`.
- Fallback mode names exactly the two controller avatars as Couch Player 1 and Couch Player 2.
- Non-avatar companions are explicitly reported as spectators.
- If the avatar count is not exactly two, the doctor refuses to guess and no state changes occur.

## Test B — minimal 1v1

1. Assign exactly one character to each player.
2. Enter `!aa_scan` and note which user or couch player is left and right.
3. Enter `!aa_spar`.
4. Have each player take at least one movement action and one attack.
5. Reduce one fighter to 0 HP.

Expected:

- Both characters enter the same combat.
- Each player can control only their assigned character as usual.
- Cross-team attacks are permitted.
- The zero-HP character enters the native downed state, remains in initiative for death saves, and can be helped or healed.
- The other user is announced as winner.
- Both characters return to full health/resources and can move after cleanup.
- They cannot target one another as enemies after cleanup.

Afterward enter `!aa_spar_status`; it should report the winner's user ID.

## Test C — simultaneous defeat

Use area/environmental damage to down the final standing member of both teams between the same 250 ms evaluation ticks, if practical.

Expected: Astral Arena reports a draw and restores both teams. This test is optional because timing it manually is difficult.

## Test D — forfeit

1. Start a fresh match.
2. Enter `!aa_forfeit left` or `!aa_forfeit right`.

Expected: the opposite side wins immediately and both teams are restored.

## Test E — emergency abort

1. Start a fresh match.
2. Enter `!aa_abort` before either side is defeated.

Expected: no winner is recorded, combat ends, hostility clears, immortality is removed, and both teams are restored.

## Test F — expanded teams

Only run this after 1v1 succeeds. Assign two same-level characters to each user and repeat Tests B, D, and E. A 4v4 test requires a compatible party-limit solution and eight controllable party members; record that dependency and its version in the report.

Summons are not roster members in this alpha. They may inherit combat relationships unpredictably, so do not use them in the first expanded-team test.

## Test G — rematch and countdown

1. Complete a 1v1 match.
2. Enter `!aa_rematch` without changing ownership.
3. Confirm the console prints a three-second countdown before hostility/combat begins.
4. After cleanup, change character assignment in an online lobby and enter `!aa_rematch` again.

Expected: every rematch rescans current team ownership rather than reusing stale character data. In split-screen fallback mode, it rescans the two current player avatars.

## What to report

Open a [GitHub playtest report](https://github.com/Thunderthief52/astral-arena/issues/new?template=playtest.yml) and include:

- the environment information listed above;
- which tests passed or failed;
- exact console commands entered;
- all `[Astral Arena]` console lines around the failure;
- `%USERPROFILE%\Documents\OsirisLogs` runtime logs, with personal paths or unrelated data removed;
- whether `!aa_abort` restored the game;
- whether reloading the pre-test save restored the game;
- screenshots or a short clip when the problem is visual or timing-related.

Never upload save files publicly without checking them for personal information. A minimal reproduction on a disposable save is preferable.

## Stop conditions

Stop the current session and reload the pre-test save if:

- a fighter dies permanently or a game-over sequence begins;
- a neutral/story NPC joins combat;
- characters remain hostile after cleanup;
- a player loses control of characters outside the active match;
- `!aa_abort` reports an engine cleanup warning;
- a crash, repeating Lua error, or save corruption warning occurs.
