# AI reward delivery recovery

Alpha.3 replaces the whole-armory delivery flag with a saved plan and per-step
receipts for the AI preparation and victory bundles. Older completed armory
flags remain respected, so upgrading does not grant another kit.

The exact randomly selected items and recipients are saved before delivery.
Before each engine operation, the journal stores an inventory snapshot, including
nested bags, item UUIDs, root templates and stack amounts. It then issues one
treasure roll or template addition. Positive inventory changes acknowledge that
step. A reload reconciles the saved snapshot before issuing anything again;
partial stack additions request only the missing quantity. Replacing a stack's
UUID does not make its pre-existing contents count as newly delivered items.

The engine can settle an operation after its call returns. Unsettled steps wait
three progression ticks before being reconsidered. A treasure roll that returned
normally may legitimately be empty. Failed operations stop automatic retries
after three attempts and keep the plan. **Ready for Battle** explicitly retries
the pending step without discarding completed steps. A failed inventory query
never substitutes an empty snapshot or issues loot blindly.

A victory and its pending plan are saved together before loot creation. This
clears the combat recovery marker, so loading during payout resumes the earned
reward instead of replaying the won fight. The next level target is saved before
XP is awarded and checked until native level-up finishes. A crash between saving
the result and awarding XP cannot silently restart the previous tier.

Regression coverage interrupts every journal save boundary, loses an engine
acknowledgement, partially adds a stack, replaces a stack UUID, fails inventory
queries, exhausts retries, reloads a partial armory, and interrupts XP delivery.
The real-bootstrap simulation uses inventory effects and completes four wins,
a mid-wave reload and a persistent elimination.

## Practical limits

This is recovery within a BG3 save, not an external transaction database. Loading
an older save rolls back both the world and the journal. It cannot repair an old
build's already-recorded partial armory because that build did not retain a plan.
Keep recipients in the party until delivery settles. Consuming, moving or trading
items during an unsettled operation can make inventory reconciliation ambiguous;
the real engine's save timing still needs verification. A native random treasure
roll is acknowledged as one operation; this does not promise exactly-once
delivery under every possible partial engine failure.

API references: [Script Extender persistence](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#persistence),
[GetTemplate](https://docs.baldursgate3.game/index.php?title=GetTemplate),
[GetStackAmount](https://docs.baldursgate3.game/index.php?title=GetStackAmount).
