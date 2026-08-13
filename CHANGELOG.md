# Changelog

## 0.3.1-alpha.2 — 2026-08-13

- Fixed the new-game blocker that left the player controlling a character-creation dummy in `AA_Arena_Main`.
- Restored BG3's supported inherited system character creator instead of misclassifying the arena as a character-creation level.
- Added the required `DB_CharacterCreationTransitionInfo` row so finished custom avatars transfer into `AA_Arena_Main` without entering a vanilla campaign level.
- Re-armed automatic XP and first-bout onboarding when arena gameplay becomes ready.

## 0.3.1-alpha.1 — 2026-08-11

- Added automatic new-game onboarding after BG3 character creation completes.
- Added per-party `AA_Arena_Main` region checks before automatic XP or encounter mutations.
- Moved AI fixture and reward validation into guarded bootstrap/start paths.
- Added automatic first-bout launch and automatic continuation after party-wide level-ups.
- Retained bootstrap, doctor, start, and continue console commands as diagnostics and recovery tools.

## 0.3.0-alpha.1 — 2026-08-10

- Added the Toolkit-authored `AA_Arena_Main` Adventure level with custom terrain, AI-grid data, player-start data, and no vanilla campaign level dependency.
- Wired Adventure startup and character-creation metadata to the canonical module UUID `29c48c80-8777-f7b5-6bb8-376c1c5d8db6`.
- Added Astral Staging plus runtime site routing for Astral Flats, Crescent Ruin, and Echelon Steps.
- Added safe party teleport and common return-to-staging cleanup while preserving the existing combat, split-screen, XP, and reward systems.
- Added Toolkit synchronization/validation, PAK installation, exact Adventure playtest instructions, and the generated project thumbnail.

## 0.2.1-alpha.1 — 2026-07-26

- Added an opt-in level-1 bootstrap that awards the vanilla level-5 XP threshold and preserves native character-build choices.
- Added party-size and completed-level gates between bootstrap and the first AI fight.
- Added twelve deterministic-random enemy formations for the three progression bouts.
- Added the dedicated new-game Adventure-module and twelve-site Toolkit specification.

## 0.2.0-alpha.1 — 2026-07-26

- Added deterministic, level-banded post-match reward offers with six unique choices.
- Added separate automatic-bundle and rare-choice state with claim-once validation.
- Added tournament, level-pool, and reward-free campaign-sparring policies.
- Added unsafe-item, ownership, recent-offer, rarity, category, template, and uniqueness filters.
- Documented the audited catalog, BG3 delivery, crash-recovery, and split-screen recipient boundaries.
- Added a session-based AI progression run with fights at levels 5, 8, and 10 and champion completion at 12.
- Added twelve anonymous vanilla AI fixture templates across three four-member teams.
- Added nonlootable, nonlethal temporary enemy spawning and deletion with abort cleanup.
- Added two level-scaled `RewardMedium` rolls and a deterministic one-of-six `+2` weapon choice after each win.
- Added exact vanilla XP advancement followed by BG3's native level-up flow.
- Added explicit solo, online co-op, and split-screen reward-recipient selection.

## 0.1.1-alpha.1 — 2026-07-26

- Added automatic 1v1 split-screen fallback using exactly two party `UserAvatar` components.
- Added avatar/reserved-user diagnostics and safe refusal for ambiguous couch rosters.
- Added a three-second pre-fight countdown.
- Added `!aa_rematch` with fresh team discovery before every replay.
- Added split-screen playtest, installation, and troubleshooting instructions.

## 0.1.0-alpha.1 — 2026-07-26

- Added console-driven two-user sparring for one to four same-level characters per user.
- Added nonlethal 1 HP defeat detection, winner/draw handling, forfeit, abort, and cleanup.
- Added multiplayer ownership diagnostics and runtime version reporting.
- Added deterministic 5 → 8 → 10 → 12 bracket and 1 → 12 level-pool run engines.
- Added guarded Windows installation, uninstallation, console setup, and release packaging.
- Added alpha playtest, troubleshooting, architecture, and future coordinator documentation.
