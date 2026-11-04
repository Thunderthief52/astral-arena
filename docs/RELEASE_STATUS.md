# Gauntlet release status — 2026-11-04

## Recovery and candidate

The surviving `C:\Users\atper\Documents\AstralArena\astral-arena.bundle` ends at
`f97b767` (0.5.0-alpha.2). The recovery folder contains the matching PAK, but no
0.6.0 PAK was found. Work continues in `astral-arena-recovered`, preserving the
other workspace copies and their unfinished changes.

0.5.1-alpha.1 added packaged Withers prompts. The new 0.6.0-alpha.1 candidate
includes all 25 tactical pieces among 114 scenery objects. Full Generate and
AI Grid Save were executed in Toolkit 4.1.1.6931813 on November 4. The grid grew
from 147,260 to 147,548 cells; its saved file changed from 300 to 4,367 bytes.
The scenery fingerprint and actual grid checksum are recorded in
`toolkit/scenery/AA_Arena_Main.navgrid.json`. Geometry validation passes for all
156 spawn points. Gameplay validation remains pending.

The Toolkit reported that scenery `Flag` must be int32, contradicting the older
uint8 assumption. Editor objects were corrected and reloaded before generating
navigation; both builders now use int32. Real-game rendering must still be checked.

## Real-game release gate

Hireling automatic leveling and equipment are user-confirmed in game on 0.5.0.
Everything below is pending on the new candidate:

- Verify Withers shows each hireling's name, class and price on host, co-op and split-screen.
- Confirm opponents engage from the 45–49 m starts with melee, ranged and caster parties.
- Knock out the entire party and confirm staging recovery precedes the game-over screen.
- Check scenery and lighting; record whether the arena is still grey.
- Complete ten consecutive clean 3 → 5 → 8 → 10 → 12 runs. Record build, party, result, reloads and defects for each; there are currently zero recorded completed runs here.
- After the Toolkit navigation rebuild: verify cover blocks movement, walk-on surfaces work, and size/rotation are correct before shipping it.

Automated tests and the engine simulation use fake game APIs and do not satisfy
these checks. Use a disposable fresh Adventure save and verify `!aa_version`.
Keep the prior PAK backup for rollback.

## Remaining implementation

Crash-safe reward delivery still needs a delivery journal and recovery design
that accounts for the gap between item creation and persistent acknowledgement.
The existing one-time flag prevents duplicates but can lose undelivered items
after interruption. Do not claim exactly-once delivery yet.

Defer the additional nine sites and graphical reward picker. Merge into main
only after engine checks pass. Keep cover/high ground as a separate candidate
if navigation work delays the gauntlet release.

## Online follow-on

Prove full-size team PvP in game first. Then implement versioned roster export
and import, result signing, Windows companion, coordinator and friend codes.
Use progression levels **3, 5, 8, 10, 12** for the online plan. The existing
eight-entrant bracket simulator still starts at level 5; it is a separate model
and needs an initiation stage if adopted for online progression.

The coordinator pairs separate BG3 lobbies; it does not host the game itself.
The design document is not evidence of a running service.
