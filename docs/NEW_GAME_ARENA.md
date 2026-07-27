# Dedicated new-game arena

## Intended player flow

The finished mode is an opt-in Adventure module, separate from the ordinary campaign add-on:

1. Enable **Astral Arena Adventure** and choose **New Game**.
2. Every human player creates a normal level-1 character through BG3 character creation.
3. On arrival in the arena staging area, Astral Arena awards the vanilla level-5 XP threshold.
4. Every player completes BG3's ordinary level-ups from 1 through 5, making all subclass, spell, feat, and multiclass decisions themselves.
5. Once every active character reports level 5, the party is moved to a deterministic-random combat site and the existing AI progression begins.
6. Victories progress the party through 5 → 8 → 10 → 12 with the existing automatic loot and one-of-six reward choice.

The game itself still owns save creation. A mod should not silently open or overwrite a save from the main menu. The Adventure module instead becomes the selected campaign when the players deliberately press **New Game**.

## Current add-on bridge

Until the custom level is packaged, a fresh campaign save can exercise the character-build bootstrap:

```text
!aa_ai_bootstrap
```

The command requires one to four active, living, out-of-combat level-1 characters. It awards only the XP needed for the vanilla level-5 threshold. Complete every native level-up, then enter:

```text
!aa_ai_start
```

The bootstrap records the initial party size and refuses to begin the tournament if active membership changed during level-up. `!aa_ai_reset` clears its session state but does not remove XP.

## Level plan

`AA_Arena_Main` will be one private level containing a neutral staging platform and twelve isolated combat sites. One level avoids carrying Act 1 quests, story NPCs, waypoints, crimes, or encounter scripts into an arena-only save.

| Site | Geometry and tactical identity |
| --- | --- |
| Astral Flats | Broad open circle; baseline balance site with no elevation. |
| Vanguard Line | Long rectangular lane with sparse symmetric half-cover. |
| Crescent Ruin | Curved broken wall with two flanking routes. |
| Twin Flanks | Open center and protected outer approaches. |
| Spearhead | Narrow forward point opening into a broad rear field. |
| Broken Ring | Incomplete circular cover with one deliberately exposed gap. |
| Four Corners | Four equal cover islands around a clear center. |
| Deep V | Two angled lanes converging on the middle. |
| Echelon Steps | Shallow symmetric elevation without inaccessible ledges. |
| Split Ranks | Two rows of low cover with multiple crossing lanes. |
| Astral Compass | Four cardinal cover points and an open central objective. |
| Hollow Square | Perimeter cover with an exposed interior fighting space. |

The first balance pass must keep both teams on valid AI grid, provide at least 8 metres between starting lines, avoid lethal chasms, and preserve more than one path between sides. Site selection is deterministic from the run and bout IDs so reloading cannot reroll the location.

## Toolkit boundary

The Script Extender code owns progression, deterministic selection, combat, rewards, and cleanup. The Windows BG3 Toolkit must author and export:

- the `AA_Arena_Main` level;
- staging and spectator regions;
- twelve player-start and twelve enemy-start anchors;
- AI-grid/navmesh coverage;
- symmetric cover/elevation props;
- safe camera bounds, lighting, and minimap data;
- the Adventure module's character-creation and startup-level metadata.

No vanilla campaign location will be used as the permanent arena. Teleporting a new party directly into `WLD_Main_A` would also load campaign quests, NPCs, triggers, and level state, defeating the isolation this mode needs.
