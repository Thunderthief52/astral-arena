# Level-pool arena variant

## Concept

This later mode takes inspiration from the asynchronous Arena loop in Super Auto Pets without copying its characters, assets, or exact rules. The pool contains player-authored **party snapshots**, not prebuilt heroes. A player creates a normal BG3 party at level 1, fights another level-1 party, then uses BG3's native level-up flow to make every class, subclass, feat, spell, ability-score, and multiclass decision for the next bout.

After each level-up, the mod records a sanitized snapshot of the party. That snapshot can later become a same-level opponent for another run, with BG3 controlling it as an AI party.

The mode is complementary to the live PvP bracket:

- **Astral Bracket:** two humans fight live; winners advance 5 → 8 → 10 → 12.
- **Level-Pool Arena:** one human develops a persistent party from level 1 → 12 and fights player-authored parties drawn from the corresponding level pool.

## Recommended first rules

- Four-character party created with BG3's normal character-creation tools.
- The same four characters persist for the entire run; there is no character draft between fights.
- Three lives and up to twelve bouts, one at each character level.
- A win adds one trophy. A loss costs one life. Either result advances the run to its next level, preventing a build from farming or becoming trapped at one level.
- After each completed bout, grant exactly enough experience to reach the next level and open BG3's native level-up flow.
- The next bout cannot begin until every surviving party member has completed that level-up.
- Class progression, subclass, feats or ability-score improvements, selected spells, prepared spells, and multiclass decisions are all player choices.
- Use standardized, level-banded equipment budgets so the mode tests builds rather than imported campaign loot.
- After every completed bout, grant a small automatic utility bundle and offer six level-banded equipment choices; the player keeps one. Losses also qualify so one defeat does not create an equipment death spiral.
- At level 12, the run ends after the final bout; surviving lives and total trophies determine its result.

Advancing after either result is the recommended prototype rule. A win-only progression option can be tested later, but it risks repeatedly matching a losing build at the same level.

## Opponent sources

The same match controller can support three increasingly ambitious pools:

1. **Developer fixtures:** a small number of known-valid parties used only to bootstrap development and fill an empty level pool.
2. **Local ghosts:** player-authored parties from prior local runs, saved as declarative snapshots and replayed by BG3 AI.
3. **Community ghosts:** sanitized snapshots uploaded by players and matched only against parties at the same level, game patch, mod set, and ruleset version.

Whole-party snapshots should be the default pool unit because formation, spell coverage, and multiclass combinations create party-level synergy. A later experimental mode could assemble four characters from separate player-authored snapshots, but that should not block the first version.

## Snapshot format

A future snapshot should contain only portable, validated choices:

```text
schema and ruleset versions
BG3 patch and required-mod fingerprints
level and party ID
race, subrace, background, and ability scores per character
class progression and subclass IDs per character
feat, ability-score, cantrip, spell, and preparation choices
allowed equipment-package IDs
formation and constrained AI role tags
random seed and anonymous provenance ID
```

It must not contain arbitrary Lua, raw savegame data, account names, chat data, or unvalidated modded assets. The service should reject unknown UUIDs, impossible level progressions, excess ability scores, illegal equipment, and mismatched ruleset versions before a snapshot enters a public pool.

The snapshot is a build recipe, not a copied save. The mod reconstructs a temporary opponent party from validated choices and deletes it during arena cleanup.

## Native level-up boundary

The prototype should avoid recreating BG3's level-up UI. Its responsibilities are narrower:

1. Finish the arena bout and restore the player's party.
2. Create and resolve the pending arena reward.
3. Award the exact experience required for the next level.
4. Wait while BG3 handles level-up decisions normally.
5. Validate that every party member is at the expected level.
6. Serialize the resulting build and equipment choices and request a same-level opponent.
7. Start the next bout only after the snapshot and opponent both validate.

If BG3 does not expose enough Script Extender data to reconstruct every native choice reliably, the first playable version can save local ghost opponents as cloned temporary characters. Public community ghosts still require the stricter declarative format.

## Design risks

- Reconstructing every legal custom character choice may require more engine data than Script Extender currently exposes.
- BG3 AI may use player-designed spell lists and multiclass builds poorly; constrained AI role tags and validation will be necessary.
- A level-1 full-party fight can be extremely random, so the ruleset may need restrained equipment and limits on explosive consumables.
- Custom classes, subclasses, spells, and items require exact mod-version compatibility. The first community ruleset should support vanilla content plus an explicit allowlist.
- Community ghosts require a companion application and external coordinator because Script Extender does not provide a suitable direct internet client.

## Shared implementation

This variant should reuse roster validation, match phases, victory and draw detection, ruleset versioning, and cleanup from Astral Arena. Native progression, lives, trophies, snapshot serialization, opponent selection, and asynchronous exchange should remain separate modules so neither mode destabilizes the other.

The proposed Eddard coordinator boundary is documented in [EDDARD_COORDINATOR.md](EDDARD_COORDINATOR.md).
The deterministic offer rules and item-safety boundary are documented in [REWARDS.md](REWARDS.md).
