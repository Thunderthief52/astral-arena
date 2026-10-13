# Changelog

## 0.5.0-alpha.1 — 2026-10-12

- Added hireling auto-kit. Before every battle each Withers follower (Fighter, Cleric, Wizard, Rogue, Paladin, Ranger) catches up on a fixed per-class build plan for its level and equips the best gear it carries.
  - Builds: Great Weapon Master fighters/paladins, Wisdom clerics with Bless, Healing Word, Spiritual Weapon, Spirit Guardians and Revivify, Intelligence wizards with Shield, Misty Step, Fireball, Haste and Counterspell, Dexterity rogues, Sharpshooter rangers with Hunter's Mark. Each step is applied exactly once and recorded in the save; spell or passive names missing from the installed game version are skipped and reported.
  - Gear: armour by real armour class within the class's proficiencies, two-handers for great-weapon builds, one-hander plus shield for clerics, finesse weapons for rogues, bows for rangers, staffs and robes for wizards, the best two rings, and accessories that raise the class's main ability. Never swaps to worse gear.
- Added `!aa_kit` (apply auto-kit now) and `!aa_party_report` (levels and equipped items for every party member).
- Hirelings still level with the party automatically; player characters keep their own native level-up choices.

## 0.4.0-alpha.3 — 2026-10-12

- Fixed the run stalling after the level-3 level-up: BG3 reports a message-box answer against whichever character the clicking player has selected (the other split-screen avatar or a hireling), and the arena only accepted the exact character the box was opened for, so "Yes" did nothing. Any active party member's answer now counts; a stranger's still does not.
- Withers' ledger accepts answers the same way and charges whichever avatar can pay, never a selected hireling with no gold.
- Added `!aa_ai_ready` to confirm the open ready prompt from the console if a click is ever lost again.
- Fixed the alpha.2 install: the copy written to the Mods folder on 2026-09-23 was actually alpha.1. Installs are now verified by checksum on the PC.
- Tactical cover is defined in the scenery manifest but is held back from the game build until the Toolkit regenerates the navigation grid for it (`tools/scenery/navgrid.py`, `record_navgrid.py`).

## 0.4.0-alpha.2 — 2026-09-23

- Fixed characters running through pillars, arches, statues, and raised floors. Root cause: `AA_Arena_Main`'s navigation grid was generated on 2026-08-10 for the bare ground plane and never rebuilt after 96 decorations were added, so BG3 treated every object as open floor. Until the grid is regenerated in the Toolkit, no solid or raised scenery is reachable: 30 ruin arches now form a ring 5 m beyond the ground's edge, the Jergal monument, Selûnite statue, and high arch are enlarged backdrop pieces past the north, west, and south edges, the Underdark cliffs and mushrooms sit outside the ground, and the Crescent floor plus the six Echelon stairs/platforms are removed.
- Fixed the level-10 and level-12 Echelon Steps enemies spawning up to 15 m past the east edge of the ground (x 110–114 on a plane that ends at x 99).
- Increased the opening distance between the teams from 30–34 m to 45–49 m across all twelve formations.
- Moved the three combat sites so every lane, spawn, and formation fits on the ground with at least 6 m to spare: Astral Flats north-east, Crescent Ruin north-west, Echelon Steps south-east. Site lighting and grass moved with them; banners stand 16 m to each side of the lane.
- The staging origin is now always the authored court centre instead of wherever the first player stood, so spawn geometry is identical in every session.
- Added `tools/scenery/build_scenery.py` (a cross-platform port of `Build-ArenaScenery.ps1`, verified to produce the same resources), `validate_scenery.py` (reachability, spawn, lane, and separation checks), and `render_map.py`, which draws `docs/arena-map.png`.

## 0.4.0-alpha.1 — 2026-09-23

- Completed the AI gauntlet rules: battles at levels 3, 5, 8, 10, and 12, and **one lost battle ends the run**. A defeat or a mutual knockout in any wave restores the party, announces a run summary to every player plus a host message box, and never schedules a rematch.
- Added a save-persistent run record (`ArenaRunState` ModVar). Eliminations and championships survive save/load, so a later save cannot silently resume a finished run.
- Fixed the one-time armory being handed out again after every reload; the delivery flag now lives in the save and is set before items are created.
- Added mid-battle save recovery: loading a save made during a wave or intermission deletes stale temporary enemies, resurrects and restores the party in staging, and restarts that battle from wave 1 without counting a loss. Previously such saves left the party stuck behind the in-combat/dead validation.
- Persisted the staging origin and fall back to the authored Jergal court instead of treating a combat site as staging after a reload.
- Battle numbering in messages now reflects the whole 3 → 12 gauntlet (for example `5/5`) even after a reload rebuilt the run from a later tier.
- Resolve knockouts the moment BG3 reports `DOWNED` or `Died`, so a total party knockout is handled by the arena before the engine's party-wipe flow, and cleared waves no longer wait for the next poll.
- Replaced free-running poll chains with one token per wave so a fast ready confirmation can never run two monitors.
- `!aa_ai_abort` now re-offers the same battle's ready prompt after about ten seconds instead of stalling until a console command.
- Collapsed repeated onboarding pause messages into a single console line.
- Fixed formation selection: the old hash ignored the bout number, so every opening wave in a run used the same formation. All twelve formations now rotate.
- Added `tests/engine_smoke.lua`, which boots the real `BootstrapServer.lua` against a scripted Script Extender/Osiris fake and plays onboarding, five battles, a mid-wave save/load, and an elimination reload end to end.
- Added `!aa_ai_unlock_run` as a developer-only override for false eliminations.
- Added a Divine-free PAK builder (`tools/pak/build_pak.py`) with LSPK v18 and `.loca` writers.

## 0.3.2-alpha.17 — 2026-08-23

- Fixed the stalled-wave root cause: enemies no longer spawn during preparation, so their vanilla hostile faction cannot begin an unmonitored fight. Accepting the ready prompt now creates the wave, joins combat, and starts victory polling as one controlled transition.
- Added a safe once-per-minute ready-prompt retry for controller and split-screen sessions; unanswered prompts never force combat.
- Reduced the level-3 initiation to a maximum of two enemies per wave, including against a four-character party.
- Replaced cloned personal kits with independently shuffled rolls across 39 audited candidates. Every character still receives all eleven useful categories: three weapon choices, three armour weights, helmet, gloves, boots, amulet, and ring.
- Fixed the actual grey-island scenery defect: the merged resource had changed Toolkit scenery flags from `uint8` to `int32`, causing BG3 to discard all 96 objects. The rebuilt PAK preserves the Toolkit schema and validation now guards it.

## 0.3.2-alpha.16 — 2026-08-23

- Replaced the forced 30-second first-wave and inter-wave countdowns with controller-safe ready prompts; players may prepare indefinitely and explicitly choose when each wave begins.
- Added a full health, spell-slot, class-resource, and cooldown refresh for living party members after every cleared non-final wave. Characters who died still require Revivify before the next wave.
- Replaced the shared 12-item armory with an eleven-piece personal kit for every party member: three proficient weapon options, three armour-weight options, a magic helmet, gloves, boots, amulet, and ring, plus the existing supply rolls and Revivify scrolls.
- Fixed the grey-island visual regression by compiling all 96 scenery objects and 16 lights into BG3's engine-loaded `Scenery/_merged.lsf` and `Lights/_merged.lsf` resources. The previous per-object files passed repository validation but were ignored by the game.
- Updated Toolkit validation to require the two merged resources so this packaging failure cannot recur.

## 0.3.2-alpha.15 — 2026-08-22

- Fixed automatic onboarding freezing after a two-player party hired two followers: bootstrap now preserves the original avatars while accepting only followers recorded by the Withers service.
- Leveled recruited followers directly instead of requiring avatar experience components, eliminating the transient unreadable-XP failure during split-screen hiring.
- Added class-appropriate starter loadouts for all six available followers and retained the full-party level-scaled armory, supply rolls, and Revivify scrolls before the first combat.
- Removed reachable planted rubble, menhirs, and loose battlefield pillars; kept the three player-to-enemy lanes clear and unobstructed.
- Added shipped Underdark cliff vistas and giant mushroom silhouettes behind the solid arena boundary, plus a larger centerline Jergal monument with stronger focal lighting.

## 0.3.2-alpha.14 — 2026-08-22

- Fixed the crash immediately after character creation by removing runtime cloning of Withers' campaign root template and the campaign-linked book used as his ledger.
- Preserved the automatic controller-safe hireling selection, one-time 300-gold grants, 100-gold level-matched followers, four-person party cap, decorated Jergal court, and all alpha.13 arena scenery.
- Added a regression guard that rejects both crash-linked root-template UUIDs and any world-ledger listener from future startup builds.
- Confirmed from the matching Script Extender and Osiris logs that both split-screen avatars reached `AA_Arena_Main` and received level-3 XP before the two runtime clones entered the level and the process terminated.

## 0.3.2-alpha.13 — 2026-08-22

- Reworked staging into a Jergal-themed Court of the Last Witness with a shipped Withers visual, Jergal monument, additional passable banners and vegetation, and blue-violet ledger lighting.
- Added a persistent arena-owned Withers service: each player avatar receives 300 gold once, six class-varied followers cost 100 gold, recruited followers join at the current arena level, and the ordinary four-person party cap remains enforced.
- Added an illuminated world ledger that reopens hireling selection between battles without loading Withers' campaign dialog or quest state.
- Increased the visual pass from 87 scenery objects and eight lights to 103 scenery objects and sixteen lights, with distinct palettes for Astral Flats, Crescent Ruin, and Echelon Steps.
- Extended validation from the three combat approaches to two staging navigation routes; any dressing inside a protected route must now explicitly support walking through or walking on it.
- Expanded defeat and draw recovery to a 30-second camp window so players can use the ledger before the automatic rematch.

## 0.3.2-alpha.12 — 2026-08-22

- Increased all twelve enemy formations to 30–34 metres from the player line, beyond a standard 9-metre move or 18-metre dash into melee range.
- Extended every validated scenery-free approach lane to cover the longer starts.
- Moved Crescent Ruin's central arch and Selûnite statue behind the new enemy line so they cannot block the expanded combat lane.

## 0.3.2-alpha.11 — 2026-08-22

- Removed arena invulnerability and Sanctuary from downed players and enemies; native follow-up attacks can now inflict death-save failures and combatants can genuinely die.
- Preserved downed and dead player states between waves instead of healing or resurrecting them automatically.
- Expanded the inter-wave gap to a 30-second revival window for Help, healing, Revivify, and resurrection scroll use without granting a rest or restoring resources.
- Added two audited Scrolls of Revivify per player to the opening armory.
- Kept full automatic resurrection and long-rest restoration at the battle boundary after final-wave victory, defeat, draw, or abort.

## 0.3.2-alpha.10 — 2026-08-22

- Removed all nine loose rocks and boulders from the active sites, moved remaining solid ruins outside three validated player-to-enemy clear lanes, and extended the eastern perimeter to contain the longer formations.
- Increased every enemy formation to 19–26 metres of opening separation with no more than eight metres of lateral spread, preventing immediate point-blank initiative swings.
- Added a once-per-run preparation armory: up to 12 audited level-appropriate magic equipment pieces plus six native level-scaled supply rolls per avatar and a 30-second equip window.
- Added 12 audited uncommon `+1` weapons and armour pieces so the level-3 initiation can always produce its six level-5 reward candidates.
- Reacted to BG3's native `DOWNED` event immediately and applied AI target exclusion alongside hidden invulnerability, preventing queued attacks from repeatedly striking a downed actor for zero damage.

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
