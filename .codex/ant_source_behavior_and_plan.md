# Ant source behavior

## Visuals and scene structure

- Use transparent role-specific pixel-art sprites for queens, workers, and defenders from `assets/Ants`; food remains `Polygon2D`. Worker sprites are 2 by 3 AntSource-local units, queens 6 by 9, and defenders 4 by 8. The shared `AntSource` world root is scaled 4x in both variants, so all game objects and world spacing render at four times their local size while CanvasLayer GUI elements remain unchanged. Preserve nearest-neighbor filtering for crisp pixel edges.
- `AntSource` owns the queen, worker, and warrior ants directly. In both variants, workers are divided as evenly as possible among queen-led groups, with group sizes differing by at most one. One queen means one group contains all workers; there is no per-group cap.
- Queens spawn at `QUEEN_SPAWN_POSITION`, 32 pixels above the AntSource origin. Workers spawn at random points inside the queen-centered 10 by 10 pixel deposit square, then join the smallest eligible leader group, with nearest leader breaking ties.
- Expired Queen Ant 1 workers disappear completely.
- Each worker-group leader uses the triangular step grid as a route-cost map. A grid edge's cost is its distance divided by the average speed multiplier at its endpoints, so route planning favors well-stepped terrain when that makes the trip faster overall. The leader moves through selected grid waypoints to food, stockpile, and other targets; before any points have been stepped, it keeps its direct route. Followers track the ant ahead without calculating their own routes. Existing step counts persist across saves and load into route planning.

## Warriors and colony defense

- Warriors are separate from worker foraging and do not carry or deposit food. The purchase button is hidden until the colony has at least 4 queens in either variant; `purchase_warrior()` also rejects purchases below that threshold. A defender costs a constant 100 food and starts with 10 health plus 2 per Warrior Endurance level. Both playable scenes disable free initial warrior spawning.
- A warrior spawns at the queen's position and patrols around grid points that have reached 100 steps, wandering within 3 pixels of its assigned point. It engages a worm only while the worm is within 12 pixels of that assigned point; otherwise it returns to its post and does not pursue the worm. With no fully stepped points, warriors hold position and do not attack. Warriors use the active variant's ant speed upgrades. Super food speed boosts affect workers only.
- After a random 12–20 second delay, a worm spawns just outside one side of the 120-pixel colony radius and travels across to just outside the opposite side. Its route is a randomized chord that may miss the colony center; it despawns after crossing the far edge. It has 24 health. A defender can attack only while the worm is in its assigned saturated-point area, attacking within 5 pixels at most once per second. Every attack deals 4 base damage plus Warrior Damage levels and costs that warrior 1 health; warriors do not take damage from the worm itself. A base warrior dies after its tenth attack if it remains alive that long; Endurance adds attacks they can survive. A new spawn delay is scheduled after a worm is defeated or escapes.
- Defeating a worm removes it and creates six red food drops, each worth 60 food, in a short line at the worm's position and orientation. These are regular harvestable food polygons, so worker groups can collect them. A worm remains present if no warrior attacks it; purchasing a warrior later sends it to the current worm.
- Warrior count, each warrior's remaining health, and warrior upgrade levels are saved. Loading restores health clamped from 1 to the current upgraded maximum. The four-queen check gates warrior purchases and upgrade purchases, but saved warriors and upgrade levels are retained even if the colony later has fewer than four queens.

### Warrior upgrades

These independent food upgrades are available in both variants after the colony reaches four queens. They do not change worker behavior. Each affects current warriors immediately and applies to warriors purchased later.

- **Warrior Damage:** +1 damage per attack per level, from the base of 4. First cost 250 food, ×1.5 cost growth, maximum 4 levels. This reduces attacks needed to defeat a 24-health worm.
- **Warrior Endurance:** +2 maximum health per level, from the base of 10. First cost 400 food, ×1.6 cost growth, maximum 5 levels. Buying a level adds 2 current health to each living warrior. Warriors still lose 1 health each time they attack.
- **Warrior Training:** +10% movement speed multiplicatively per level. First cost 600 food, ×1.7 cost growth, maximum 5 levels. This applies while patrolling and pursuing worms, and does not change worker speed or the attack interval.

Upgrade levels are saved with the shared game state, and warrior health saves against the upgraded maximum. The existing warrior purchase cost, patrol radius, attack interval, and worm/drop behavior remain unchanged.

## Cluster foraging

- Workers spawn at random points in the queen-centered 10 by 10 pixel deposit square and join the smallest eligible leader group; ties favor the nearest leader. The number of active groups is limited by the queen count, and group sizes rebalance when queens or workers are added or workers expire.
- Each cluster leader chooses the nearest live regular food polygon not already assigned to another group traveling outbound or gathering. If that source is claimed, the leader checks the next-nearest live source; when all live sources are claimed, it scouts and searches again after arrival. All cluster ants travel there in order with 10 pixels between ant centers. Each ant immediately scatters to a random point within the polygon radius plus 1 pixel upon arrival, without waiting for the rest of the cluster, and harvests its carry amount.
- Ants scatter and gather independently after arrival. The group waits until every member has finished its gather timer, then followers track the ant ahead of them on the return trip. Each ant deposits its carried food as soon as it reaches its stockpile position. Ants spread to scattered nearby positions and wander locally while waiting for the whole group; once everyone arrives, the leader searches for another source and the group follows together.
- A worker that enters the idle state joins the smallest eligible leader group, with nearest leader breaking ties; if none is eligible, it starts a group and resumes searching.
- If a target polygon depletes while a group is traveling to it, affected ants leave that trip and rejoin the smallest eligible leader group, with nearest leader breaking ties. An ant without an eligible leader starts a new group and immediately resumes searching.
- If a target polygon depletes while a group is gathering, each ant looks for the smallest eligible leader group, with nearest leader breaking ties. An ant without one returns to the deposit square and delivers carried food; there it searches for a leader again, joining the smallest group or starting one if needed.
- If no live regular food polygon exists, the cluster scouts within `food_search_range` of the queen's spawn point and searches again after arrival. Tiny death drops are not valid forage targets.
- If a worker expires while carrying food, it drops that amount at the worker's death position as a 1 by 1 pixel polygon. These drops are not selected by cluster leaders.
- Regular food polygons use the `food_polygons` group and expose `food_remaining` and `harvest(amount)`. Death drops use a separate group and are ignored by foraging. Regular depleted sources respawn; depleted drops are removed without creating replacement sources.

## Queen Ant 1

- `scenes/queen_ant_1.tscn` uses the shared foraging system. Each queen spawns one worker every five seconds. The queen production upgrade increases this spawn rate; queens do not generate food directly.
- Workers live for 30 seconds. Each worker-lifetime upgrade level adds 10 seconds to workers spawned afterward. Queen Ant 1 does not sell workers directly.
- Carry adds one food per trip per level; speed adds 10% per level; food efficiency increases new source stockpiles by 10% per level.

## Incremental 1 and economy

- Incremental 1 keeps passive queen production and its worker purchase. Worker prices start at 5 food and grow by 1.25x; queen prices start at 1,000 and grow by 1.5x.
- Upgrades start at 25 food and their independent next prices grow by 1.15x. Large UI values use K, M, and B abbreviations.
- `GameState` owns food, counts, prices, upgrade levels, and the `user://game_state.json` save. New/reset games start with 250 food and one queen.

## Food source behavior

- Regular sources are irregular polygons with 5, 6, 7, or 9 sides, 50–300 starting food, and a maximum diameter below 200 pixels.
- Workers choose the nearest unclaimed live source globally, skipping sources another group is traveling to or gathering from. Collection uses arrival and timers; do not add collision-based collection.
- Keep food behind ants with the `FoodSources` container's negative z-index.
