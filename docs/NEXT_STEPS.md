# Astral Arena next steps

This roadmap converts the broad milestones into testable releases. Dates are intentionally omitted until the corresponding engine boundary has survived a real BG3 playtest.

## 0.1.x — campaign-space engine validation

Goal: prove that temporary PvP can start and clean up safely in ordinary online and split-screen sessions.

Current `0.1.1-alpha.1` candidate includes:

- online teams discovered from multiplayer ownership;
- automatic split-screen 1v1 fallback from exactly two player avatars;
- transactional preparation and cleanup;
- nonlethal one-HP defeat, win/draw/forfeit/abort;
- countdown, rematch, diagnostics, and reproducible packaging.

Exit criteria:

- successful 1v1 online and split-screen reports on current BG3/SE versions;
- no persistent hostility, immortality, combat lock, or ownership changes after ten consecutive rematches;
- clean abort during countdown and combat;
- known behavior for chasms, transformations, summons, disconnects, and simultaneous defeat.

## 0.2 — dedicated arena and explicit teams

Goal: remove reliance on players manually finding a safe campaign location and allow deliberate roster construction.

Planned work:

- capture or create two reusable arena start zones;
- teleport fighters in while saving their original level/position/rotation;
- restore every fighter to their origin after the result or abort;
- add a ready check before the countdown;
- add an indexed/manual team builder so split-screen companions can be assigned explicitly for couch 2v2–4v4;
- prevent spectators, summons, and nearby NPCs from joining;
- expose arena/rules state to both screens without requiring the console for ordinary actions.

Exit criteria:

- repeated 4v4 setup and teardown without campaign-state leakage;
- controller-only start, ready, forfeit, rematch, and exit flow;
- safe recovery from one controller disconnecting or a player leaving during setup.

## 0.3 — fair rules and AI fixtures

Goal: make matches repeatable enough to evaluate builds rather than setup accidents.

The `0.3.2-alpha.3` candidate combines the existing level-5, level-8, and level-10 AI fixtures, deterministic rewards, split-screen-safe native XP progression, a completion-gated system-character-creation transfer, automatic level-1 onboarding, and the first Toolkit-authored Adventure level with a shipped-asset visual pass.

`AA_Arena_Main` now starts independently of vanilla campaign locations and provides a decorated staging area plus Astral Flats, Crescent Ruin, and Echelon Steps. The runtime moves the cooperative party between these sites and returns it through common cleanup. The first visual pass adds 66 shipped-asset objects and eight accent lights; Toolkit Game Mode inspection also moved Echelon inward from the eastern terrain edge. This playable foundation must pass new-game, solo, ordinary co-op, and split-screen engine playtests before the map expands.

Planned work:

- regenerate and validate AI-grid navigation around the first tactical props, then complete named anchors, spectator boundaries, camera bounds, final lighting, and minimap data for the first three sites;
- add and validate the remaining nine combat sites;
- replace the remaining console-only reward choice with controller-safe in-game UI;
- standardized resource restore and equipment-budget validation;
- no-surprise start and deterministic initiative policy experiments;
- configurable preparation time and hard-control guardrails;
- expand each existing level-5, level-8, and level-10 fixture into a seedable opponent pool;
- seedable encounter selection using the existing match controller;
- ruleset fingerprints included in every result;
- expand the initial audited `+2` weapon catalog to armor, jewelry, and class-aware choices;
- replace `RewardMedium` with Astral Arena-owned level-banded utility tables;
- add crash-safe reward-delivery recovery without duplicating items.

Exit criteria:

- a solo or cooperative party can complete ten consecutive 5 → 8 → 10 → 12 AI runs without cleanup or progression leakage;
- live and AI matches share victory, cleanup, and validation code;
- illegal levels/items/mod fingerprints fail before arena mutation;
- no story/debug/summoned item can enter an offer, and interrupted delivery has a tested recovery path.

## 0.4 — live eight-entrant bracket

Goal: make the 5 → 8 → 10 → 12 tournament playable across separate two-player lobbies.

Planned work:

- signed roster/result export and import;
- quarterfinal, semifinal, and final lobby handoff;
- native level-up gate after each advancement;
- bracket view, friend codes, reconnect/forfeit rules, and spectator summaries;
- no public ranking until result tampering and disputes have defined handling.

## 0.5 — private Eddard coordinator

Goal: automate friend-code pairing and bracket persistence for invited testers.

Planned work:

- Windows companion outbox/inbox bridge;
- authenticated coordinator on `127.0.0.1:8095`;
- strict schemas, UUID allowlists, request limits, quarantine, SQLite backups, and audit metadata;
- private `arena.ozlabs.dev` Cloudflare ingress only after local health/security checks;
- explicit rollback and no raw saves, scripts, account names, or chat data.

## Later — player-authored level pool

The asynchronous 1 → 12 mode follows the same safe snapshot pipeline. Players keep their own party and use BG3's native level-up screens; the pool stores validated party build recipes rather than prebuilt designer characters. Community ghosts begin only after local ghosts can be reconstructed and controlled reliably by BG3 AI.
