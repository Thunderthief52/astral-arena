# Dedicated new-game arena

## Intended player flow

The finished mode is an opt-in Adventure module, separate from the ordinary campaign add-on:

1. Enable **Astral Arena Adventure** and choose **New Game**.
2. Every human player creates a normal level-1 character through BG3 character creation.
3. On arrival in the arena staging area, Astral Arena awards the vanilla level-3 XP threshold.
4. Every player completes BG3's ordinary level-ups from 1 through 3, making all subclass, spell, and multiclass decisions themselves.
5. Once every active character reports level 3, the party moves to Astral Flats for a three-enemy initiation.
6. Victories progress the party through 3 → 5 → 8 → 10 → 12; each win fully restores the party and automatically distributes a generous loot bundle without blocking progression on a prompt.

The game itself still owns save creation. A mod should not silently open or overwrite a save from the main menu. The Adventure module instead becomes the selected campaign when the players deliberately press **New Game**.

## Current playable foundation

Version `0.3.2-alpha.5` includes a checked-in BG3 Toolkit Adventure project, split-screen-safe automatic onboarding, continuous post-bout recovery/reward flow, a shipped-asset visual pass with perimeter walls, and an installable PAK. `StartupLevelName` points to the custom `AA_Arena_Main` gameplay level under Adventure UUID `29c48c80-8777-f7b5-6bb8-376c1c5d8db6`. Character creation is intentionally inherited from the `GustavX` dependency so BG3 uses its supported system character creator; an Osiris pre-event callback adds the required transition row for `AA_Arena_Main`. A delayed `SYS_CC_*` fallback is armed only after `CharacterCreationFinished`, never by the creator scene's initial `LevelGameplayReady` event. No vanilla campaign gameplay level is referenced.

The level currently provides a decorated safe staging circle, valid terrain and AI-grid data, player-start data for up to four players, and three coordinate-separated combat sites. Ninety-six deterministic scenery objects and eight accent lights use only shipped BG3 root templates, including 30 oversized ruin arches around the active arena perimeter. Astral Flats retains a broad open lane framed by boulders and broken menhirs; Crescent Ruin has a curved floor, arches, rubble, and a Selûnite landmark; Echelon Steps keeps its spawn lane clear while placing staggered high ground along the safer northern edge. The runtime records the staging origin, moves the party to each site for its bout, and returns the party after every result.

Fresh level-1 characters begin progression automatically after BG3 reports that character creation is finished. The runtime first confirms every party member is in `AA_Arena_Main`, validates enemy and reward templates internally, awards the vanilla level-3 XP threshold without choosing build decisions, and waits for the whole recorded party to finish native level-ups. It then moves the party to Astral Flats and starts the initiation bout. The same watcher starts later bouts after party-wide level-up completion; console start commands remain recovery-only.

## Level plan

`AA_Arena_Main` is now a private custom level containing the staging foundation and the first three combat sites. The target remains twelve authored sites in one level. This avoids carrying Act 1 quests, story NPCs, waypoints, crimes, or encounter scripts into an arena-only save.

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

The Script Extender code owns progression, deterministic selection, combat, rewards, and cleanup. The checked-in Windows BG3 Toolkit project now exports:

- the `AA_Arena_Main` level, inherited system character creation, and explicit post-creation transition;
- custom terrain and AI-grid data without a vanilla campaign location dependency;
- a decorated staging foundation and up-to-four-player start data;
- three visually distinct combat sites built from shipped assets and safe return-to-staging behavior;
- project metadata and a 16:9 Adventure thumbnail.

The deterministic visual manifest lives at `toolkit/scenery/AA_Arena_Main.scenery.json`; `scripts/Build-ArenaScenery.ps1` converts it into Toolkit level resources. Future passes must add explicit named anchors, spectator boundaries, camera bounds, final lighting/minimap data, navmesh regeneration around tactical props, and the remaining nine combat sites.

No vanilla campaign location will be used as the permanent arena. Teleporting a new party directly into `WLD_Main_A` would also load campaign quests, NPCs, triggers, and level state, defeating the isolation this mode needs.
