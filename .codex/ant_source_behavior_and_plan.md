# Ant source behavior

## Visuals and scene structure

- Use `Polygon2D` ants and food; do not add imported game art.
- `AntSource` owns the queen, worker, and warrior ants directly. Workers form logical leader/follower clusters capped at 10 ants each.
- Queens and every worker spawn at `QUEEN_SPAWN_POSITION`, 32 pixels above the AntSource origin. Workers then move as ordered leader/follower clusters.
- Expired Queen Ant 1 workers disappear completely.

## Cluster foraging

- Workers spawn at random points in the queen-centered 10 by 10 pixel deposit square. They join the nearest leader within 40 pixels if its cluster has fewer than 10 workers; otherwise they become a leader.
- Each cluster leader chooses the nearest live regular food polygon. All cluster ants travel there in order with 9 pixels between ant centers. Once the cluster arrives, each ant moves to a random point within the polygon radius plus 1 pixel and harvests its carry amount. The leader's gather timer controls when the cluster returns; it waits until every ant has gathered before starting the return.
- The cluster returns together in order to a shared random point in the queen-centered 10 by 10 pixel deposit square, delivers all carried food, then repeats the search. A replacement leader continues the group's current destination.
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
- Workers choose the nearest live source globally. Collection uses arrival and timers; do not add collision-based collection.
- Keep food behind ants with the `FoodSources` container's negative z-index.
