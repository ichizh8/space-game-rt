# Balance Sheets

Open in Apple Numbers. Files:

- **creatures.csv** — all enemy types: HP, damage, speed, rewards, drops
- **wildlife.csv** — huntable creatures: behaviors, ingredient drops, zones
- **economy.csv** — sell prices, repair/refuel costs, upgrade costs, death penalties, XP
- **restaurant.csv** — ingredients, dishes, revenue, reputation tiers, upgrades

## Workflow

1. Tune numbers here first
2. Copy changed values into the relevant `.gd` script or `data/*.json`
3. Push and test

## Future Systems

- **Shields + shield regen** — separate shield layer on top of hull HP. Regens over time when not taking damage. Design TBD.

## Flagged Items

- `credits: 9999` start value in `game_state.gd` — dev value, needs tuning before release
- `player_speed_bonus` starts at `0.0` now (was 120.0 — fixed)
- Debug save line still visible in main menu — remove before release
