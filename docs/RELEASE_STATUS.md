# Gauntlet release status — 2026-11-04

## Recovery and candidate

The surviving `C:\Users\atper\Documents\AstralArena\astral-arena.bundle` ends at
`f97b767` (0.5.0-alpha.2). The recovery folder contains the matching PAK, but no
0.6.0 PAK was found. Work continues in `astral-arena-recovered`, preserving the
other workspace copies and their unfinished changes.

0.5.1-alpha.1 is a maintenance candidate with packaged Withers prompts. It retains
the open-field terrain from 0.5.0. The manifest's tactical props remain excluded
until the navigation grid matches them. Do not record the existing flat grid as
current merely to enable cover. Rebuild it in the Toolkit first.

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
