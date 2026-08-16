# AI progression playtest

## What this candidate tests

Version `0.3.2-alpha.5` tests a continuous, non-blocking solo/co-op progression run with visible knockouts, full between-round recovery, automatic generous loot, save-tier recovery, and a new level-3 initiation:

```text
fight at L3 -> loot for L5 -> native level-up
fight at L5 -> loot for L8 -> native level-up
fight at L8 -> loot for L10 -> native level-up
fight at L10 -> loot for L12 -> native level-up -> champion
```

The level-12 party is the completed championship build. There is no level-12 fight in this ruleset; a later exhibition or boss bout can be added separately.

The whole active party fights together against four temporary AI enemies. That includes an ordinary solo party, online co-op players on the same party, or two split-screen players cooperating against the AI. The current maximum is four active party members.

## Important safety boundary

This mode really awards inventory items and experience. `!aa_ai_reset` resets only session state; it cannot remove awarded XP or reliably identify every generated treasure item.

1. Use a disposable non-Honour save with a fresh party, or a recovery save whose real custom characters are at level 5, 8, or 10.
2. Create a named manual save such as `BEFORE ASTRAL AI TEST`.
3. Do not save or reload during an active fight. Reloading in staging at level 5, 8, or 10 resumes from that tier.
4. Use vanilla experience progression. Disable level-curve, level-cap, automatic-level, and randomized-loot mods for the first test.
5. Confirm the new game loaded `AA_Arena_Main`, then dismiss summons and temporary followers before starting.
6. Reload `BEFORE ASTRAL AI TEST` to undo the entire experiment.

The temporary enemies are made non-lootable, stop at one HP, and are deleted during cleanup. Never loot their bodies. All intended rewards come from the arena reward step.

## Automatic onboarding and optional diagnostics

Normal Adventure play requires no bootstrap, doctor, start, or continue command. After character creation, Astral Arena:

1. confirms the whole party is inside `AA_Arena_Main`;
2. validates every AI and reward template before mutating the run;
3. grants each fresh level-1 avatar the vanilla level-3 XP threshold without multiplying ordinary party-wide XP;
4. waits for every player to finish their own native level-up choices; and
5. starts the next bout when the complete party reaches the required level.

For troubleshooting only, `!aa_version`, `!aa_ai_status`, and `!aa_ai_doctor` remain available. Stop and report the console output if automatic onboarding pauses or a template is missing.

## Run the progression

### Fresh-character onboarding

Create the characters and finish every normal BG3 level-up through level 3 when prompted. The automatic bootstrap grants XP rather than calling `SetLevel`, so every player remains responsible for their own class, subclass, spell, and multiclass decisions.

The Adventure PAK starts in the private `AA_Arena_Main` level. Read [ADVENTURE_PLAYTEST.md](ADVENTURE_PLAYTEST.md) for installation and startup checks.

### Level 3 initiation

1. Confirm every active party member finishes leveling to 3.
2. Confirm the party moves from staging to Astral Flats and starts the countdown.
3. Fight the three Astral Initiates. After victory, confirm the full restore, automatic loot delivery, and XP target for level 5.

### Level 5 tournament opener

1. Confirm every active party member finishes leveling to 5 and is not already in combat.
2. Confirm automatic validation moves the whole party from staging to Astral Flats and starts the three-second countdown.
3. Fight the four-member Astral Vanguard normally.

Expected after victory:

- defeated enemies and players fall knocked out at one HP, leave initiative, and are not attacked again;
- all temporary enemies disappear;
- the player party leaves combat, returns to staging, and receives a full long-rest-equivalent resource restore;
- every avatar receives four level-scaled treasure rolls and the six rare candidates are distributed round-robin across party inventories.

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
| `!aa_ai_status` | Show current tier and whether combat or level-up is pending. |
| `!aa_ai_abort` | Stop an active fight, restore players, and delete temporary enemies. Use `!aa_ai_continue` only to replay the ready tier manually. |
| `!aa_ai_reset` | Forget the current session run. Does not remove items or XP. |

If combat cleanup, inventory, or progression looks wrong, stop immediately and reload the pre-test save.

## Current intentional limitations

- One developer-authored AI team per combat level.
- The playable-alpha fallback distributes all six rare candidates instead of enforcing one-of-six; a graphical controller-friendly selection screen remains planned.
- The rare catalog is an intentionally conservative set of ten vanilla `+2` weapons; armor, jewelry, named build-defining items, and class-aware weighting come after catalog auditing.
- The automatic bundle uses four calls per player to the vanilla `RewardMedium` table. It will become an Astral Arena-owned treasure table after balance reports.
- Run details are session-only, but a party at level 5, 8, or 10 can reconstruct the remaining progression after reload.
- No automatic equipment-budget enforcement yet.
- The dedicated map has a first shipped-asset visual pass, but final terrain materials, navigation around tactical props, spectator boundaries, camera bounds, and minimap data remain unfinished.
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
