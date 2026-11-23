# Incremental 1 unlockables (MVP)

This is the conversationally agreed unlockable plan for the Incremental 1 scene. These are in-scene upgrades, separate from the main menu buttons that select Incremental 1 or Queen Ant 1. The unlocks appear progressively as the player meets their requirements; this note does not define a separate tech-tree scene.

## Upgrade rules

- Food costs grow from the listed starting cost by the listed multiplier after each purchase.
- New Ant cost is rounded up to the next whole food, as explicitly agreed.
- Carry capacity increases by one food per worker per trip per purchase.
- These are the current balance values; saved games keep their food, ants, and upgrade levels, while next prices are recalculated from the current curves.
- Requirements are unlock requirements; no additional per-purchase requirements were specified.

## 1. New Ant

- Available at the start.
- First purchase costs 10 food.
- Each purchase adds one ant.
- Cost multiplier: 1.02 per purchase.
- Round each next cost up to the next whole food.
- No maximum was specified.

## 2. Ant Carry Capacity

- Unlock requirement: 10 ants.
- First purchase costs 100 food.
- Cost multiplier: 1.35 per purchase.
- Each purchase adds 1 food to every worker's trip yield.
- No maximum was specified.

## 3. Ant Speed

- Unlock requirements: 20 ants and at least 1 Ant Carry Capacity upgrade.
- First purchase costs 250 food.
- Cost multiplier: 1.35 per purchase.
- Each purchase multiplies ant speed by 1.1.
- Maximum total speed increase: 100% (2x base speed). Stop allowing purchases at the cap; if a purchase would exceed the cap, clamp speed to the cap.

## 4. Food Source Size

- Unlock requirement: at least 5 Ant Carry Capacity upgrades.
- First purchase costs 250 food.
- Cost multiplier: 1.6 per purchase.
- Each purchase adds 25 food to each live food source and to future food sources.
- No maximum was specified.

## 5. Queen Amount

- Unlock requirement: 25 workers.
- First purchase costs 500 food.
- Cost multiplier: 1.5 per purchase.
- Each purchase adds one queen and makes one additional leader available for ants to follow at once.
- Maximum: 10 queens total.

## 6. Food Source Amount

- Starts with 1 food source.
- Unlock requirement: at least 2 queens.
- First purchase costs 350 food.
- Cost multiplier: 1.5 per purchase.
- Each purchase adds one food source.
- Maximum: 20 food sources total.

## 7. Worker Gathering Time

- Unlock requirement: at least 1 level of Worker Speed.
- First purchase costs 250 food.
- Cost multiplier: 1.4 per purchase.
- Maximum: 6 upgrades.
- Each purchase reduces the gathering pause by 10% multiplicatively (base duration × 0.9^level).
