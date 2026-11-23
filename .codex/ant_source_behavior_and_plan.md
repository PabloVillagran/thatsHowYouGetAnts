# Ant source behavior

## Visuals and scene structure

- Use `Polygon2D` ants and food; workers are 2 pixels wide by 3 pixels long. Do not add imported game art.
- `AntSource` owns the queen, worker, and warrior ants directly. In both variants, workers are divided as evenly as possible among queen-led groups, with group sizes differing by at most one. One queen means one group contains all workers; there is no per-group cap.
- Queens spawn at `QUEEN_SPAWN_POSITION`, 32 pixels above the AntSource origin. Workers spawn at random points inside the queen-centered 10 by 10 pixel deposit square, then join the smallest eligible leader group, with nearest leader breaking ties.
- Expired Queen Ant 1 workers disappear completely.

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
