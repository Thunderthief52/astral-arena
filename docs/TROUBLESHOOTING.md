# Troubleshooting

## Astral Arena does not appear in BG3 Mod Manager

Verify that this exact file exists:

```text
<BG3 install>\Data\Mods\AstralArena\meta.lsx
```

Refresh BG3 Mod Manager. The unpacked project may appear in green. Move it to the active list, save the order, and export it to the game.

## No Script Extender console opens

Install Script Extender through BG3 Mod Manager's Tools menu. Then run `Enable-SE-Console.ps1` with the correct BG3 `Data` path. It preserves the existing `ScriptExtenderSettings.json` beside a timestamped backup and enables `CreateConsole`, `EnableLogging`, and `LogRuntime`.

## The console opens but `!aa_help` is unknown

Look for an error mentioning `AstralArena`, `BootstrapServer.lua`, or `RequiredVersion`. Confirm:

- both players have the same Astral Arena files;
- `Data\Mods\AstralArena\ScriptExtender\Config.json` exists;
- Script Extender reports API v30 or newer;
- Astral Arena is active in the exported load order.

Then enter `!aa_version` and attach the console output to a report.

## `!aa_doctor` finds only one user

The game has not assigned a party character to the guest. Open Escape → Multiplayer/Session and drag at least one character to the second player. Run `!aa_doctor` again.

## `!aa_doctor` reports mixed levels

Every registered fighter must currently have the same character level. Level the lower characters or move them out of the active party for this test.

## Combat does not start for every fighter

Enter `!aa_abort`, reload the pre-test save, and retry in a smaller, flatter area with one character per player. Disable AI, party-control, initiative, and PvP mods. Report which characters entered combat and which remained outside it.

## A character remains at 1 HP or cannot fight after cleanup

First try `!aa_abort`. If it says no match is active or does not restore the character, reload the manual save made before the match. Do not continue the campaign from the affected state. Attach the relevant runtime log.

## Characters remain hostile

Reload the pre-match save immediately. Record both characters' names, whether they originally shared a faction/party, and whether another PvP or faction-changing mod was active.

## Where are logs?

With the provided console script, Script Extender uses its default log directory under:

```text
%USERPROFILE%\Documents\OsirisLogs
```

Search the most recent files for `[Astral Arena]`. Remove unrelated personal paths or information before posting publicly.
