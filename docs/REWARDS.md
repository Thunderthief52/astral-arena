# Arena reward system

## Player loop

Astral Arena rewards come from the arena, never from an opponent's body or inventory.

After a qualifying match, the recipient receives two independent rewards:

1. A small automatic bundle containing level-banded consumables or utility resources.
2. A rare equipment offer containing six distinct choices. The player keeps exactly one.

The first balance policy is:

| Mode | Result | Automatic bundle | Choose one of six |
| --- | --- | --- | --- |
| Live bracket | Win | Yes | Yes |
| Live bracket | Loss | No | No |
| Level-pool run | Win, loss, or draw | Yes | Yes |
| Campaign sparring | Any | No | No |

Level-pool losses still grant a reward because a party that loses both a life and access to equipment is likely to enter a downward spiral. Trophies and remaining lives continue to distinguish successful runs. Campaign sparring stays reward-free by default because it is a disposable engine-safety test and must not become a campaign item farm.

## Initial level and rarity bands

| Character level | Rare-offer range |
| --- | --- |
| 1–4 | Uncommon |
| 5–8 | Uncommon through Rare |
| 9–10 | Rare through Very Rare |
| 11–12 | Rare through Legendary |

Rarity is a ceiling, not a complete balance model. Every catalog entry also needs an explicit minimum/maximum level based on its effects. A build-defining Uncommon item can be less appropriate than a narrow Rare item.

The automatic bundle uses the same four level bands but a separate consumable/utility pool. The intended engine delivery call is `GenerateTreasure(inventoryHolder, treasureTableId, level, finder)` against Astral Arena-owned treasure tables. Those tables are not enabled until their contents have been audited.

## Deterministic offer generation

`Core/Rewards.lua` is pure Lua and owns the persisted reward state. Given the same offer ID, seed, level, catalog, ownership history, and ruleset, it returns the same six choices.

Generation performs these checks before weighting:

- valid logical item ID, root template ID, rarity, and category;
- item level range intersects the match level;
- rarity is inside the level band;
- item is not marked story, debug, summoned-only, or excluded;
- the logical item and root template are unique;
- already-owned items are excluded;
- recently offered items are suppressed when at least six other choices exist;
- optional ruleset category allowlists are applied.

Selection is weighted without replacement. It targets no more than two choices from one equipment category while alternatives exist, and removes other members of a selected `uniqueGroup`. If six legal unique items cannot be produced, generation fails closed instead of padding the offer with duplicates or unsafe items.

The resulting save record includes:

```text
schema version
offer and recipient IDs
mode, match result, match ID, and level band
deterministic seed
automatic-bundle delivery state
six sanitized choices
open/claimed state and selected choice ID
```

Only server-authoritative state may accept a claim. A choice outside the offer is rejected, and an offer can be claimed once.

## Catalog boundary

The runtime catalog builder will inspect `Weapon`, `Armor`, and selected `Object` stats through Script Extender, but discovery does not imply eligibility. An item must pass the arena allowlist and carry:

```text
logical ID and root template UUID
translated display name
rarity and equipment category
minimum and maximum arena level
source mod UUID and version fingerprint
unique group, when applicable
explicit safety flags
```

The source mod fingerprint matters for live PvP and community ghosts: every participant must be able to resolve the selected template. Vanilla-only is the first public ruleset. Modded rewards can be added as separate, exact-version rulesets.

The initial audit must exclude at least:

- quest, story, narrative, key, and scripted-use items;
- debug/test templates and `DONOTUSE` variants;
- temporary, summon, wild-shape, pact, and conjured weapons;
- unobtainable NPC equipment and items with missing templates;
- duplicate stat records pointing to the same root template;
- consumables that bypass the arena's action or resource rules;
- items whose scripts mutate campaign quests, approval, factions, or permanent character state.

The other randomized-loot mod mentioned during design may contain useful UX or filtering ideas. Record its exact name and version before comparing behavior; do not copy its catalog or code blindly.

## Engine delivery boundary

There are two engine mutations, both server-only:

- automatic bundle: `Osi.GenerateTreasure(holder, arenaTableId, level, finder)`;
- chosen item: `Osi.TemplateAddTo(rootTemplateId, holder, 1, 1)`.

The six candidate items are never spawned as part of selection. After a server validates the recipient and open offer, it persists the selected choice, invokes `TemplateAddTo` once, and records delivery diagnostics. Split-screen needs an explicit recipient rule: the default proposal is the winning controller's avatar inventory, with a controller-visible recipient confirmation before delivery.

Cross-save exactly-once delivery needs an engine receipt or item tag that can be reconciled after a crash. Until that is implemented, in-game delivery remains gated behind an alpha setting and testers must use disposable saves.

## Native reward UI candidate

BG3's journal reward data already supports generated rewards, optional treasure tables, an optional-pick count, and the game's normal Reward UI. Larian documents hidden boosters specifically for rewards that should not appear as ordinary quests. An Astral Arena hidden booster with six optional tables and an optional count of one is therefore the preferred first experiment.

This route should preserve the game's own mouse, keyboard, and controller interaction instead of recreating item cards in Script Extender UI. It still needs an engine test for repeated rewards, per-user behavior in online play, split-screen viewport ownership, deterministic table contents, cancellation, and save/reload recovery. The pure reward record remains authoritative even if the native panel renders the choice.

## UI and progression order

The normal between-match sequence should be:

1. Resolve combat and restore the arena.
2. Create and persist the post-match reward.
3. Deliver the automatic bundle.
4. Show six large item cards with comparison tooltips.
5. Confirm one choice and deliver it to the selected avatar.
6. Open BG3's native level-up flow.
7. Validate level and equipment budget before the next match.

Prefer the native hidden-booster Reward UI. A Script Extender client UI remains the fallback if hidden boosters cannot meet repeated arena, per-user, or deterministic-choice requirements. Controller navigation, two local viewports, and a timeout/reconnect path are required before split-screen playtesting.

## Implementation status

Implemented:

- deterministic level-banded one-of-six offer generation;
- mode/result policy;
- ownership, recent-offer, category, uniqueness, and unsafe-item filters;
- separate automatic-reward and rare-choice state;
- claim-once validation;
- automated pure-Lua coverage.

Still gated:

- audited vanilla item catalog and Astral Arena treasure tables;
- persistent queue integration with bracket and level-pool state;
- server delivery wrapper and crash reconciliation;
- native hidden-booster Reward UI experiment, with Script Extender UI as fallback;
- split-screen recipient confirmation;
- equipment-budget validation and live multiplayer mod fingerprints.

## Technical references

- [Larian modding docs: adding quest rewards](https://docs.baldursgate3.game/index.php?title=Journal:_Adding_Quest_Rewards)
- [Larian modding docs: `GenerateTreasure`](https://docs.baldursgate3.game/index.php?title=GenerateTreasure)
- [Larian modding docs: `TemplateAddTo`](https://docs.baldursgate3.game/index.php?title=TemplateAddTo)
- [BG3 Script Extender API](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md)
- [Open Trials of Tav–Archipelago integration used for interoperability research](https://github.com/Zoltun456/Archipelago-BG3-ToT)

The Trials integration was inspected for concepts such as stat discovery, root-template validation, rarity filters, mod filters, and item blacklists. Its implementation was not copied.
