# AI progression playtest

## What this candidate tests

Version `0.3.1-alpha.2` adds a repaired character-creation handoff and automatic new-game onboarding to the continuous solo/co-op progression run:

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
5. Confirm the new game loaded `AA_Arena_Main`, then dismiss summons and temporary followers before starting.
6. Reload `BEFORE ASTRAL AI TEST` to undo the entire experiment.

The temporary enemies are made non-lootable, stop at one HP, and are deleted during cleanup. Never loot their bodies. All intended rewards come from the arena reward step.

## Automatic onboarding and optional diagnostics

Normal Adventure play requires no bootstrap, doctor, start, or continue command. After character creation, Astral Arena:

1. confirms the whole party is inside `AA_Arena_Main`;
2. validates every AI and reward template before mutating the run;
3. grants the vanilla level-5 XP threshold to fresh level-1 characters;
4. waits for every player to finish their own native level-up choices; and
5. starts the next bout when the complete party reaches the required level.

For troubleshooting only, `!aa_version`, `!aa_ai_status`, and `!aa_ai_doctor` remain available. Stop and report the console output if automatic onboarding pauses or a template is missing.

## Run the progression

### Fresh-character onboarding

Create the characters and finish every normal BG3 level-up through level 5 when prompted. The automatic bootstrap grants XP rather than calling `SetLevel`, so every player remains responsible for their own class, subclass, spell, feat, and multiclass decisions.

The Adventure PAK starts in the private `AA_Arena_Main` level. Read [ADVENTURE_PLAYTEST.md](ADVENTURE_PLAYTEST.md) for installation and startup checks.

### Level 5

1. Confirm every active party member finishes leveling to 5 and is not already in combat.
2. Confirm automatic validation moves the whole party from staging to Astral Flats and starts the three-second countdown.
3. Fight the four-member Astral Vanguard normally.

Expected after victory:

- defeated enemies stop at one HP;
- all temporary enemies disappear;
- the player party leaves combat, returns to staging, and is fully restored;
- the console prints six deterministic `+2` weapon choices and numbered reward recipients.

Choose one item and its recipient. For example, to give option 3 and the automatic bundle to party member 2:

```text
!aa_ai_pick 3 2
```

The selected character receives:

- two level-8 rolls from BG3's native `RewardMedium` treasure table;
- exactly one selected weapon from the six-choice offer.

The whole party then receives enough vanilla experience to reach level 8. Complete every normal BG3 level-up screen, including all class, subclass, feat, spell, and multiclass choices. The next bout starts automatically when every active party member reaches level 8.

### Levels 8 and 10

Repeat the same loop against Astral Bastion at level 8 in Crescent Ruin and Astral Judicators at level 10 on Echelon Steps. Rewards are generated at the next tier: level 10 after the second fight and level 12 after the final fight. Every cleanup should return the party to staging.

After the final reward, finish every native level-up to 12. Completion is automatic. Expected:

```text
Astral Arena champion complete at level 12.
```

## Recovery commands

| Command | Effect |
| --- | --- |
| `!aa_ai_status` | Show current tier and whether combat, reward selection, or level-up is pending. |
| `!aa_ai_abort` | Stop an active fight, restore players, and delete temporary enemies. Use `!aa_ai_continue` only to replay the ready tier manually. |
| `!aa_ai_reset` | Forget the current session run. Does not remove items or XP. |

If combat cleanup, inventory, or progression looks wrong, stop immediately and reload the pre-test save.

## Current intentional limitations

- One developer-authored AI team per combat level.
- Console-driven reward selection rather than BG3's native Reward UI.
- The rare catalog is an intentionally conservative set of ten vanilla `+2` weapons; armor, jewelry, named build-defining items, and class-aware weighting come after catalog auditing.
- The automatic bundle uses two calls to the vanilla `RewardMedium` table. It will become an Astral Arena-owned treasure table after the first balance reports.
- No run persistence across save/reload, crash, or game restart.
- No automatic equipment-budget enforcement yet.
- The dedicated map is a sparse greybox foundation: site identity currently comes from safe coordinate separation, not final cover/elevation art.
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
