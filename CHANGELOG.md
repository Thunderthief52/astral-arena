# Changelog

## 0.3.2-alpha.9 — 2026-08-22

- Added a true level-12 championship battle instead of crowning the party as soon as its final level-up completes.
- Added four party-scaled Astral Exarch waves at Echelon Steps, with rotating frontline, support, caster, and striker orders.
- Added a staged, party-wide championship celebration after the final loot bundle and full-rest restoration.
- Allowed real level-12 arena saves to reconstruct directly into the championship bout.

## 0.3.2-alpha.8 — 2026-08-22

- Turned every arena battle into a multi-wave event: two waves at levels 3 and 5, then three waves at levels 8 and 10.
- Kept every wave scaled to the active player-character count and rotated role order between waves for varied two- and three-character rosters.
- Added a three-second inter-wave breather that deletes cleared enemies and restores downed teammates to partial health without refreshing surviving characters, spell slots, class resources, or cooldowns.
- Reserved the existing full long-rest-equivalent restoration, abundant loot bundle, and level progression for victory over the final wave.

## 0.3.2-alpha.7 — 2026-08-22

- Scaled each AI bout to the active player-character count instead of always spawning the full four-enemy fixture; each reduced roster deliberately keeps a frontline and ranged threat.
- Kept full four-enemy fixtures for four-character parties, with the three-member initiation fixture remaining capped at three.
- Rebuilt all arena scenery with explicit solid movement, click-through, walk-on, and decorative flags so pillars, arches, rocks, and cover no longer behave like pass-through decoration.

## 0.3.2-alpha.6 — 2026-08-15

- Replaced one-hit-point arena elimination with BG3's native zero-hit-point downed state and `DeathSavingThrows` passive for both player and AI combatants.
- Kept downed combatants in initiative so they can roll death saves or receive help, while temporary hidden protection prevents AI attacks from farming automatic failures.
- Removed the protection immediately when healing or a natural recovery returns a combatant to the fight; bout cleanup still resurrects and fully rests everyone safely.

## 0.3.2-alpha.5 — 2026-08-15

- Replaced the unreliable post-bout prompt dependency with a continuous controller-safe flow: victory loot and progression resolve automatically, while defeats and draws fully restore the party and replay the tier after five seconds.
- Made arena defeat visibly nonlethal with BG3's knocked-out state, removed defeated actors from combat, and protected them from continued AI attacks.
- Added a true between-round party restore for spell slots and class resources in addition to healing and cooldown reset.
- Increased victory loot to four level-scaled treasure rolls per player and distributed all six deterministic rare candidates round-robin across the party for this playable-alpha test.
- Added a three-enemy level-3 initiation bout before the existing 5 → 8 → 10 → 12 tournament, while allowing saves already at levels 5, 8, or 10 to resume at their current tier.
- Added 30 oversized shipped-asset perimeter arches, increasing the visual pass to 96 scenery objects and eight accent lights.

## 0.3.2-alpha.4 — 2026-08-15

- Added native, controller-safe post-bout prompts for defeat retries and draw replays.
- Added a no-console victory flow that cycles through six deterministic reward candidates and every party recipient.
- Added packaged English fallback localization plus runtime item and recipient names for the arena prompts.
- Added defeat-retry state recovery and regression coverage for retry, dismiss/reopen, reward cycling, and recipient selection.

## 0.3.2-alpha.3 — 2026-08-15

- Fixed local split-screen onboarding awarding level-5 XP to only one independently owned avatar.
- Made XP delivery idempotent for both per-avatar and ordinary party-wide engine behavior, including characters still completing native level-up choices.
- Added automatic repair for a real-character arena save left at mixed levels, such as one split-screen avatar at level 5 and the other at level 1.
- Kept the automatic onboarding poll alive after transient runtime errors so a repaired party proceeds to Astral Flats without console commands.
- Added regressions for split-screen XP, party-wide XP, pending level-up state, and mixed-party recovery.

## 0.3.2-alpha.2 — 2026-08-15

- Fixed fresh New Game startup transferring BG3's four temporary, naked, classless 1-HP character-creation dummies into `AA_Arena_Main` before the character creator opened.
- Restricted the `SYS_CC_*` fallback to sessions that have actually emitted `CharacterCreationFinished`; `LevelGameplayReady` for character creation can no longer trigger an arena transfer.
- Added regression tests for pre-creation placeholders, completed-character recovery, Adventure scoping, and level scoping.

## 0.3.2-alpha.1 — 2026-08-15

- Added 66 deterministic shipped-asset scenery objects and eight colored accent lights across Astral Staging, Astral Flats, Crescent Ruin, and Echelon Steps.
- Gave each playable space a distinct landmark and tactical silhouette with stone platforms, arches, pillars, rubble, rocks, vegetation, and stepped high ground.
- Moved Echelon Steps and its encounter center inward after a Toolkit Game Mode inspection found the eastern props and possible enemy positions too close to the terrain edge.
- Added a reproducible scenery manifest/generator plus Toolkit validation for duplicate entries, generated-file counts, UUIDs, and missing artifacts.

## 0.3.1-alpha.3 — 2026-08-13

- Moved `DB_CharacterCreationTransitionInfo` out of Script Extender's restricted `SessionLoaded` callback and into the unrestricted Osiris `CharacterCreationFinished` pre-event.
- Added a guarded recovery transfer for finished Astral Arena parties stranded in a `SYS_CC_*` character-creation scene.
- Added Toolkit validation that rejects the restricted registration pattern and requires both the pre-event registration and recovery transfer.

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
