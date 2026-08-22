# AI progression playtest

## What this candidate tests

Version `0.3.2-alpha.9` tests a continuous, non-blocking solo/co-op progression run with party-sized multi-wave battles, solid tactical scenery, native death saves, final-wave long rests and loot, save-tier recovery, a level-3 initiation, and a true level-12 championship:

```text
2 waves at L3 -> long rest + loot for L5 -> native level-up
2 waves at L5 -> long rest + loot for L8 -> native level-up
3 waves at L8 -> long rest + loot for L10 -> native level-up
3 waves at L10 -> long rest + loot for L12 -> native level-up
4 waves at L12 -> long rest + final loot -> champion celebration
```

The level-12 party faces four rotating waves of Astral Exarchs at Echelon Steps. Clearing the last wave completes the run and triggers staged champion announcements for every player.

The whole active party fights each wave against a matching number of temporary AI enemies. Reduced rosters rotate roles between waves while retaining melee and ranged or magical pressure. The level-3 fixture is capped at three enemies per wave; later fixtures are capped at four. This includes a solo avatar, online co-op players, or split-screen players cooperating against the AI.

## Important safety boundary

This mode really awards inventory items and experience. `!aa_ai_reset` resets only session state; it cannot remove awarded XP or reliably identify every generated treasure item.

1. Use a disposable non-Honour save with a fresh party, or a recovery save whose real custom characters are at level 5, 8, 10, or 12.
2. Create a named manual save such as `BEFORE ASTRAL AI TEST`.
3. Do not save or reload during an active fight. Reloading in staging at level 5, 8, 10, or 12 resumes from that tier.
4. Use vanilla experience progression. Disable level-curve, level-cap, automatic-level, and randomized-loot mods for the first test.
5. Confirm the new game loaded `AA_Arena_Main`, then dismiss summons and temporary followers before starting.
6. Reload `BEFORE ASTRAL AI TEST` to undo the entire experiment.

The temporary enemies are made non-lootable, receive the same native death-save passive as players, and are deleted during cleanup. Never loot their bodies. All intended rewards come from the arena reward step.

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
3. Clear both party-sized Astral Initiate waves (up to three enemies per wave). Confirm there is no rest or loot after wave 1, then confirm the full restore, automatic loot delivery, and XP target for level 5 after wave 2.

### Level 5 tournament opener

1. Confirm every active party member finishes leveling to 5 and is not already in combat.
2. Confirm automatic validation moves the whole party from staging to Astral Flats and starts the three-second countdown.
3. Fight both party-sized Astral Vanguard waves normally. A two-character split-screen party should face exactly two opponents per wave, beginning with Vanguard Warrior + Vanguard Raider and then Vanguard Gish + Vanguard Devastator.

Expected after victory:

- players and enemies enter BG3's native downed state at zero HP, make death saves while teammates remain active, and can recover through healing or a natural 20;
- downed actors receive temporary protection against AI farming; that protection is removed immediately when they recover;
- enemies from a cleared non-final wave disappear, downed allies recover at partial health, and the next wave arrives after three seconds without refreshing resources or delivering loot;
- after the final wave, all temporary enemies disappear and the player party returns to staging with a full long-rest-equivalent resource restore;
- every avatar receives four level-scaled treasure rolls and the six rare candidates are distributed round-robin across party inventories.

The whole party then receives enough vanilla experience to reach level 8. Complete every normal BG3 level-up screen, including all class, subclass, feat, spell, and multiclass choices. The next bout starts automatically when every active party member reaches level 8.

### Levels 8 and 10

Repeat the same loop against Astral Bastion at level 8 in Crescent Ruin and Astral Judicators at level 10 on Echelon Steps. Rewards are generated at the next tier: level 10 after the second fight and level 12 after the Judicators. Every cleanup should return the party to staging.

After the Judicator reward, finish every native level-up to 12. Four Astral Exarch waves should begin automatically. After clearing wave four, expected notifications include:

```text
FINAL WAVE CLEARED — THE ASTRAL EXARCHS HAVE FALLEN!
THE ASTRAL ARENA ERUPTS — YOUR PARTY ARE THE CHAMPIONS!
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
