# Balance Sheets

Open in Apple Numbers. Three files:

- **creatures.csv** — all enemy types: HP, damage, speed, rewards, drops
- **economy.csv** — sell prices, repair/refuel costs, upgrade costs, death penalties, XP
- **restaurant.csv** — ingredients (from creature drops), dishes, revenue, reputation tiers, upgrades

## Workflow

1. Tune numbers here first
2. Copy changed values into the relevant `.gd` script or `data/*.json`
3. Push and test

## Future Systems

- **Shields + shield regen** — separate shield layer on top of hull HP. Regens over time when not taking damage. Design TBD.

## Flagged Items

- `credits: 9999` start value in `game_state.gd` — dev value, needs tuning before release
- `player_speed_bonus` starts at `120.0` in `game_state.gd` (line ~13) — looks intentional but unusually high, verify
- Carrier HP not confirmed — check `carrier.gd` directly
- Void Sentinel HP not confirmed — check `void_sentinel.gd` directly
- Restaurant system does not exist in code yet — this tab is the design spec
