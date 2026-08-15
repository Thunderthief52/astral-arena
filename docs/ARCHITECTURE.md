# Astral Arena architecture

## Boundary

The project separates deterministic tournament rules from BG3 engine calls. This matters because bracket behavior can be tested without launching the game, while all volatile engine integration remains behind server-side adapters.

```text
BG3 / Script Extender
        |
        v
Server Controller ---- Persistence (ModVars)
        |
        +---- BG3 Adapter ---- Sparring + Solo Arena orchestrators
        |                           |
        v                           v
Tournament + Match + Roster + Solo Run + Rewards domain modules
```

The domain modules contain no `Ext` or `Osi` calls. They accept plain Lua tables and return plain Lua tables that Script Extender can serialize into a savegame.

## Alpha sparring runtime

The first engine playtest uses BG3's existing campaign space rather than a custom level. `Roster` first groups current `DB_PartyMembers` rows by `GetReservedUserID`. Two ordinary multiplayer users can each contribute one to four same-level characters.

Ordinary online teams use `GetReservedUserID`. If fewer than two ownership groups exist, roster resolution checks the `UserAvatar` component exposed by Script Extender. Exactly two party avatars become Couch Player 1 and Couch Player 2; other party members are omitted. This fallback never bypasses level, death, or existing-combat validation and refuses any avatar count other than two.

`Sparring` owns the runtime lifecycle and delegates engine mutations to `Bg3Adapter`:

1. Fully restore fighters, enable combat, and make them temporarily immortal.
2. Run a three-second notification countdown.
3. Apply temporary hostility across every opposing pair and enter combat.
4. Poll hit points every 250 ms. One HP is considered nonlethal defeat.
5. Remove defeated fighters from combat and resolve the match when a side has none left.
6. Leave combat, clear individual relations against opposing factions, remove immortality, resurrect if required, and restore health/resources.

The active sparring match is intentionally session-only. Saving during a match is unsupported; this avoids persisting temporary relationships or incomplete cleanup state.

Sparring rewards are disabled by default. The current campaign-space mode exists to validate combat and cleanup and must not modify a real save's inventory as a side effect of an engine test.

## AI progression runtime

`SoloRun` models a three-bout progression independently of BG3: fight at level 5, claim a level-8 reward, fight at level 8, claim a level-10 reward, fight at level 10, and claim a level-12 reward. Confirming that the entire party completed its final native level-up crowns the champion. A level-12 exhibition fight is deliberately outside this first ruleset.

`SoloArena` connects that model to the engine. It treats the active one-to-four-character player party as one cooperative team, so the same flow supports solo, online co-op, and local split-screen. For each tier it validates and creates four anonymous vanilla character templates as temporary, non-lootable NPCs, sets their faction and level, and passes both sides through the same nonlethal `Match` lifecycle used by sparring. Cleanup restores the players and permanently deletes the temporary opponents.

After a victory, the runtime generates a deterministic six-choice offer at the next tier. The chosen recipient receives two native `RewardMedium` treasure rolls and one selected item; then every player-party member receives the vanilla experience delta for the next target level. BG3's ordinary level-up screen remains authoritative for all class, subclass, spell, feat, and multiclass decisions. The next bout cannot begin until all active party members report the expected level.

The AI run and recent-offer history are session-only in this candidate. Delivered items and experience are real save mutations, so a clean reset requires reloading the pre-playtest save.

`ArenaBootstrap` adds the pre-tournament gate. It accepts only a one-to-four-character level-1 party, records its size, awards the vanilla level-5 experience target through the adapter, and then waits for every character to complete BG3's native level-up flow. It never selects classes, subclasses, spells, feats, or multiclasses. The first bout cannot start if the final level or active party size differs from the recorded bootstrap.

Automatic onboarding is armed by BG3's `CharacterCreationFinished` Osiris event. `SoloArena:autoAdvance` polls only while the Adventure session is active, treats mixed co-op levels as a normal wait state, runs template validation internally, and starts a bout only when the entire party reaches the expected level. `Bg3Adapter.isPartyInArena` checks `GetRegion` for every member before any automatic mutation, so enabling the module cannot bootstrap or start a normal campaign party.

`ArenaLayouts` contains twelve deterministic four-enemy formations. The runtime selects a formation from the run and bout IDs, so an identical run cannot reroll positioning by reissuing a command. `ArenaSites` currently maps the three progression bouts to Astral Flats, Crescent Ruin, and Echelon Steps. `Bg3Adapter` records the initial staging origin, teleports each party member with explicit offsets and AI-grid ground snapping, and returns the party during common cleanup.

The new-game experience is a separate Toolkit-authored Adventure module with `AA_Arena_Main` as its startup gameplay level. Its canonical UUID is `29c48c80-8777-f7b5-6bb8-376c1c5d8db6`. Character creation is inherited from the `GustavX` system scene. A `CharacterCreationFinished` Osiris `before` listener inserts `DB_CharacterCreationTransitionInfo("AA_Arena_Main", "")` from an unrestricted engine callback before the shared character-creation rules evaluate the event. If BG3 nevertheless reports `LevelGameplayReady` for a `SYS_CC_*` scene while Astral Arena is the active Adventure, the recovery path calls `TeleportPartiesToLevelWithMovie` to move the finished party into the arena. `LevelGameplayReady` for `AA_Arena_Main` then re-arms automatic onboarding. Keeping gameplay separate from the add-on prevents normal campaign saves from being redirected and avoids inheriting the NPCs, quests, crimes, and triggers of a reused vanilla region.

The level's first art pass is data-driven. `AA_Arena_Main.scenery.json` records shipped root-template UUIDs, transforms, tactical cover flags, and accent lights. `Build-ArenaScenery.ps1` derives stable object UUIDs and converts one local resource per object with LSLib, while `Validate-ToolkitProject.ps1` checks the manifest and generated inventory. Runtime site offsets remain authoritative for party and enemy placement; the visual pass deliberately surrounds rather than replaces those clear spawn lanes. Toolkit Game Mode inspection moved Echelon Steps inward to keep the full encounter on solid terrain. Named anchors, spectator boundaries, final camera/minimap work, AI-grid regeneration around tactical props, and nine additional sites remain Toolkit work.

## Tournament model

The initial bracket always has eight entrants and seven matches:

```text
QF1 (1 v 8) --\
               SF1 --\
QF2 (4 v 5) --/       \
                        F1 --> champion
QF3 (2 v 7) --\       /
               SF2 --/
QF4 (3 v 6) --/
```

The quarterfinal is fought at level 5. Its winners advance at level 8, semifinal winners advance at level 10, and the final winner is crowned at level 12. Starting at level 5 ensures every core class has its defining combat package; the smaller later jumps preserve continuity while still adding meaningful build decisions.

## Multiplayer shape

Each bracket match is intended to run in its own normal BG3 multiplayer lobby with two human peers. Each peer controls up to four registered characters. This avoids requiring all eight entrants and all tournament characters to coexist in one game session. The alpha validates this two-user match boundary before tournament coordination is connected.

The mod owns in-session state and rules. A later coordinator can exchange signed roster/result documents between separate lobbies. Script Extender has no external networking API, so automatic internet matchmaking must be a separate optional service or launcher.

## Persistence

`TournamentState` is registered as a persistent, server-owned ModVar and synchronized read-only to clients. Changes reassign the complete table so Script Extender marks it dirty. The serialized structure deliberately contains no functions, userdata, metatables, or cyclic references.

## Reward boundary

`Rewards` is another deterministic domain module. It converts a curated item catalog plus match level, result, recipient, seed, ownership, and recent-offer history into a serializable offer of six unique choices. It never calls `Ext` or `Osi` and never inspects or copies an opponent's inventory.

Automatic utility loot and the selected equipment item are separate delivery records. The AI candidate currently uses two native `RewardMedium` rolls for the automatic bundle and one root-template addition for the claimed choice. A later balance pass will replace the shared table with Astral Arena-owned treasure tables. The preferred presentation experiment is BG3's native hidden-booster Reward UI because it already supports generated rewards, optional treasure tables, pick counts, tooltips, and controller interaction. The deterministic offer remains authoritative regardless of presentation.

Runtime stat discovery belongs in a server catalog adapter, not the domain module. Discovery results must pass a vanilla allowlist and story/debug/summon/template/provenance validation before they can enter an offer.

## Reuse policy

Trials of Tav and other arena/PvP mods are architectural references. No third-party code or assets are copied into this repository. If we later incorporate GPL code, that will be isolated, attributed, and distributed under compatible terms. Closed-source or restricted mods will only be used as optional dependencies with their authors' permission.
