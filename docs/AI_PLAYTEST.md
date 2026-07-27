# AI progression playtest

## What this candidate tests

Version `0.2.1-alpha.1` adds a level-1 bootstrap to the continuous solo/co-op progression run:

```text
fight at L5 -> loot for L8 -> native level-up
fight at L8 -> loot for L10 -> native level-up
fight at L10 -> loot for L12 -> native level-up -> champion
```

The level-12 party is the completed championship build. There is no fourth fight in this ruleset; a later level-12 exhibition or boss bout can be added separately.

The whole active party fights together against four temporary AI enemies. That includes an ordinary solo party, online co-op players on the same party, or two split-screen players cooperating against the AI. The current maximum is four active party members.

## Important safety boundary

This mode really awards inventory items and experience. `!aa_ai_reset` resets only session state; it cannot remove awarded XP or reliably identify every generated treasure item.

1. Use a disposable non-Honour save with a level-5 party.
2. Create a named manual save such as `BEFORE ASTRAL AI TEST`.
3. Do not save or reload during the three-fight run. AI run state is session-only in this candidate.
4. Use vanilla experience progression. Disable level-curve, level-cap, automatic-level, and randomized-loot mods for the first test.
5. Move to a wide, flat area without neutral, allied, or story NPCs. Dismiss summons and temporary followers.
6. Reload `BEFORE ASTRAL AI TEST` to undo the entire experiment.

The temporary enemies are made non-lootable, stop at one HP, and are deleted during cleanup. Never loot their bodies. All intended rewards come from the arena reward step.

## Validate without changing the game

Enter:

```text
!aa_version
!aa_ai_doctor
```

Expected:

- Astral Arena reports `0.2.1-alpha.1`.
- The doctor finds one to four active same-level party members.
- All twelve anonymous vanilla AI character templates validate.
- All ten initial reward item templates validate.
- The doctor prints `No game state was changed`.

Stop and report the complete console output if any template is missing. Do not attempt `!aa_ai_start` after a failed doctor check.

## Run the progression

### Optional fresh-character bootstrap

To begin with newly created level-1 characters, enter `!aa_ai_bootstrap`. Complete every normal BG3 level-up through level 5, then continue with `!aa_ai_start` below. The bootstrap grants XP rather than calling `SetLevel`, so every player remains responsible for their own subclass, spell, feat, and multiclass decisions.

This bridge does not yet move the party into a private map. Read [NEW_GAME_ARENA.md](NEW_GAME_ARENA.md) for the dedicated Adventure-module plan.

### Level 5

1. Confirm every active party member is level 5 and not already in combat.
2. Enter `!aa_ai_start`.
3. Return to the game during the three-second countdown.
4. Fight the four-member Astral Vanguard normally.

Expected after victory:

- defeated enemies stop at one HP;
- all temporary enemies disappear;
- the player party leaves combat and is fully restored;
- the console prints six deterministic `+2` weapon choices and numbered reward recipients.

Choose one item and its recipient. For example, to give option 3 and the automatic bundle to party member 2:

```text
!aa_ai_pick 3 2
```

The selected character receives:

- two level-8 rolls from BG3's native `RewardMedium` treasure table;
- exactly one selected weapon from the six-choice offer.

The whole party then receives enough vanilla experience to reach level 8. Complete every normal BG3 level-up screen, including all class, subclass, feat, spell, and multiclass choices. When every active party member displays level 8, enter:

```text
!aa_ai_continue
```

### Levels 8 and 10

Repeat the same loop against Astral Bastion at level 8 and Astral Judicators at level 10. Rewards are generated at the next tier: level 10 after the second fight and level 12 after the final fight.

After the final reward, finish every native level-up to 12 and enter `!aa_ai_continue` one last time. Expected:

```text
Astral Arena champion complete at level 12.
```

## Recovery commands

| Command | Effect |
| --- | --- |
| `!aa_ai_status` | Show current tier and whether combat, reward selection, or level-up is pending. |
| `!aa_ai_abort` | Stop an active fight, restore players, and delete temporary enemies. The tier can be replayed with `!aa_ai_continue`. |
| `!aa_ai_reset` | Forget the current session run. Does not remove items or XP. |

If combat cleanup, inventory, or progression looks wrong, stop immediately and reload the pre-test save.

## Current intentional limitations

- One developer-authored AI team per combat level.
- Console-driven reward selection rather than BG3's native Reward UI.
- The rare catalog is an intentionally conservative set of ten vanilla `+2` weapons; armor, jewelry, named build-defining items, and class-aware weighting come after catalog auditing.
- The automatic bundle uses two calls to the vanilla `RewardMedium` table. It will become an Astral Arena-owned treasure table after the first balance reports.
- No run persistence across save/reload, crash, or game restart.
- No automatic equipment-budget enforcement yet.
- No dedicated arena map; nearby NPCs and campaign geometry can still interfere.
- Vanilla cumulative XP thresholds are required.

## What to report

Use the existing [GitHub playtest report](https://github.com/Thunderthief52/astral-arena/issues/new?template=playtest.yml) and include:

- BG3, Script Extender, Astral Arena, and BG3 Mod Manager versions;
- full active load order;
- solo, online co-op, or split-screen;
- active party size and classes at each tier;
- `!aa_ai_doctor` output;
- which AI tier failed;
- all console lines around spawning, cleanup, reward delivery, and XP;
- whether `!aa_ai_abort` worked;
- whether reloading the pre-test save fully recovered the game.
