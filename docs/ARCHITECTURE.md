# Astral Arena architecture

## Boundary

The project separates deterministic tournament rules from BG3 engine calls. This matters because bracket behavior can be tested without launching the game, while all volatile engine integration remains behind server-side adapters.

```text
BG3 / Script Extender
        |
        v
Server Controller ---- Persistence (ModVars)
        |
        +---- BG3 Adapter ---- Sparring Orchestrator
        |                           |
        v                           v
Tournament + Match + Roster domain modules
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

## Reuse policy

Trials of Tav and other arena/PvP mods are architectural references. No third-party code or assets are copied into this repository. If we later incorporate GPL code, that will be isolated, attributed, and distributed under compatible terms. Closed-source or restricted mods will only be used as optional dependencies with their authors' permission.
