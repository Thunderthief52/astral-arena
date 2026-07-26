# Playable milestones

## M0 — deterministic foundation (complete)

- Eight-entrant bracket and 5/8/10/12 progression
- Party roster and match lifecycle
- Persistent state
- Console-driven simulation
- Automated tests

## M1a — console-driven campaign-space sparring (alpha playtest)

- Detect two connected peers through assigned party characters
- Support one to four same-level fighters per side
- Apply temporary hostility and start combat
- Use temporary immortality and one HP as nonlethal defeat
- Detect victory/draw and restore relationships, combat state, health, and resources
- Provide scan, doctor, status, forfeit, and abort commands
- Resolve collapsed split-screen ownership through exactly two player-avatar components
- Provide a start countdown and ownership-rescanning rematch
- Package guarded Windows installer and detailed playtest protocol

## M1b — dedicated playable 4v4 arena

- Validate both clients have the required mod version
- Teleport teams to fixed start zones in one reused arena
- Begin combat after both players confirm readiness
- Add graphical readiness and result prompts
- Validate teardown against disconnects, summons, transformations, and environmental deaths
- Add explicit split-screen companion assignment for couch 2v2 and 4v4

## M2 — fair PvP ruleset

- Alternating-team initiative or reliable turn dividers
- No surprise round
- Preparation timer and start-zone containment
- One-round cap or diminishing protection for hard crowd control
- Full resource reset between games
- Equipment budget and banned-item validation
- Disconnect, forfeit, and host-migration safeguards
- Deterministic post-match reward queue with an audited vanilla item catalog
- Automatic utility bundle plus a controller-friendly one-of-six equipment choice
- Split-screen recipient confirmation and duplicate-delivery recovery

## M3 — AI training tournament

- Curated AI parties at levels 3, 6, and 9
- Arena-aware positioning profiles
- Same match controller and PvP rules used by multiplayer
- Eight-team solo bracket with repeatable seeds

## M4 — eight-entrant tournament

- Export/import of signed roster snapshots
- Bracket UI and result confirmation
- Separate two-player lobby handoff for each match
- Spectator-friendly summary and completed bracket

## M5 — optional matchmaking coordinator

- Account-free friend codes first
- Lobby pairing and bracket persistence
- Result dispute workflow
- Authentication and anti-tamper work only before public rankings

## Parallel future mode — level-pool arena

- One encounter at every character level from 1 through 12
- Keep one player-created party and make class, spell, feat, and multiclass choices through BG3's native level-up flow
- Fight a player-authored party snapshot from the same level, with developer fixtures only as empty-pool fallbacks
- Lives/trophies structure inspired by asynchronous auto-battlers
- Reward every completed bout with level-banded arena loot, including losses, before native level-up
- Exchange validated snapshots through a Windows companion and the Eddard coordinator
- Reuse the match engine without coupling this mode to the live PvP bracket

The full proposal is in [LEVEL_POOL_VARIANT.md](LEVEL_POOL_VARIANT.md).
