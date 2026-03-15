# Space Game RT — Project Document

**Engine:** Godot 4.4 (WebGL/WASM export)
**Platform:** iOS, Android, Web (mobile-first)
**Genre:** Roguelite space exploration / survival
**Live URL:** https://ichizh8.github.io/space-game-rt/
**Repo:** https://github.com/ichizh8/space-game-rt
**Current version:** v52

---

## Concept

Top-down space exploration roguelite. Fly through a procedurally generated sector, mine resources, complete quests, fight enemies, dock at planets and stations, and grow your captain across deaths. One life per run — die and lose your ship progress, but your captain's XP and perks persist forever.

---

## Controls

| Input | Action |
|---|---|
| Virtual joystick (bottom-center) | Steer ship |
| FIRE button (bottom-right) | Toggle auto-fire on/off |
| COCKPIT button (top-left) | Open captain interface |
| Land / Mine / Dock button (center) | Context action when near object |

---

## Core Systems

### Roguelite Progression Split

**Resets on death:**
- Credits
- Resources (ore, crystal, scrap) — lose 50%
- Ship upgrades (hull capacity, fuel capacity, speed, damage)
- Artifacts collected

**Persists forever (captain progression):**
- Captain XP
- Perk points earned
- Unlocked perks and their bonuses

### Economy
- **Ore** — common drop, sells for 4 cr, used in crafting and building
- **Crystal** — rare drop, sells for 10 cr, premium crafting material
- **Scrap** — from enemies and hazard asteroids, sells for 2 cr, used for repairs
- **Fuel** — collected from asteroids/drops → auto-converts to ship fuel (+10 per canister)
- **Credits** — earned from kills, quests, selling resources

### Fuel System
Fuel is consumed by movement. Collected fuel canisters convert directly to ship fuel tank (not cargo). Refuel at planets (20 cr / +50 fuel) or stations (25 cr / +50 fuel).

---

## World

### Procedural Sector Generation

Objects spawn dynamically around the player with minimum safe distances:

| Object | Min distance from player |
|---|---|
| Asteroids | 200px |
| Enemies | 320px |
| Planets / Stations | 400px |
| Stars | 550px |
| Black holes / Artifacts | 350px |

Sector checks run every 0.5s. Objects despawn at 1500px from player.

### Biome System

Active biome shifts every 45 seconds. Biomes affect enemy spawn composition:

| Biome | Enemies | Notes |
|---|---|---|
| Mixed | All types | Default |
| Asteroid Belt | Pirates, interceptor packs | Dense asteroids |
| Debris Field | Drones, turrets, battleships | Scrap-heavy |
| Deep Space | Battleships, drones | Unlocks beyond 1200px from origin |
| Nebula | Light opposition | Rare artifacts |

### Celestial Objects

**Planets**
- 15+ named procedurally colored worlds
- Land to open 4-tab menu: Quests, Services, Buildings, Storage
- Unique quests per planet (complete once)
- Build mining plants, manufacturing, storage depots, shipyards
- Repair / refuel / sell resources

**Stars (Suns)**
- 15 named stars (Sol Proxima, Vega Prime, etc.)
- Warning zone (200px): 5 hp/s heat damage
- Danger zone (110px): 18 hp/s heat damage
- HUD notification on approach

**Black Holes**
- 15 named (Sagittarius A*, The Maw, Void Omega, etc.)
- Gravity pull: inverse-square force within 400px
- Event horizon (45px): teleports player 1500–3200 units, deals 20 hull damage

**Space Stations**
- 8 named stations (Outpost Kepler, Port Orion, etc.)
- Dock action from HUD
- Simple services: repair (scrap), refuel (credits), sell resources

**Hazard Asteroid Belts**
- Dense clusters of dark-red asteroids
- 6 hp damage on contact, disappear on hit
- Shootable and destroyable, 50% chance 1 scrap drop

**Artifacts**
- Rare collectibles with stat bonuses
- Persistent in Cockpit inventory across session
- Reset on death (future: make persistent like captain XP)

---

## Enemies

| Enemy | HP | Speed | Behavior | XP | Credits |
|---|---|---|---|---|---|
| Pirate | 30 | 130 | Aggressive chase, burst fire | 15 | 20 |
| Drone | 60 | 80 | Heavy shot, patrol + chase | 25 | 35 |
| Interceptor | 20 | 240 | Fast approach → hover → proximity bomb (2.2s ARM, 30 dmg AOE) | 8 | 10 |
| Battleship | 180 | 55 | Patrol/chase, 3-bullet spread shot | 60 | 80 |
| Turret | 45 | 0 | Stationary, rotates to track, rapid fire (0.7s cooldown) | 20 | 25 |

All enemies drop world loot orbs on death. Orbs drift, blink, auto-collect at 40px, expire in 18s.

---

## Captain Progression (Cockpit)

### Perks (9 total, 3 branches)

**Combat**
- `Iron Will` — +20 max hull
- `Steady Aim` — +20% bullet damage
- `Last Stand` — take 30% less damage below 20% hull

**Exploration**
- `Efficient Miner` — +25% mining yield
- `Fuel Saver` — -25% fuel consumption
- `Salvager` — always drop extra scrap from kills

**Trade**
- `Keen Eye` — +15% XP from all sources
- `Negotiator` — +20% sell prices
- `Lucky Find` — better artifact tier chance (stub)

### XP Rewards
| Action | XP |
|---|---|
| Kill pirate | 15 |
| Kill drone | 25 |
| Kill interceptor | 8 |
| Kill battleship | 60 |
| Kill turret | 20 |
| Mine asteroid | 5 |
| Collect artifact | 50 |

### Instant Crafting (Cockpit → Crafting tab)
| Recipe | Cost | Effect |
|---|---|---|
| Emergency Repair | 8 ore + 6 scrap | +40 HP |
| Fuel Synthesis | 5 crystal + 4 ore | +40 fuel |
| Energy Core | 12 crystal + 6 ore | +120 credits |
| Nano Repair Kit | 18 ore + 8 crystal + 10 scrap | +80 HP |
| Fuel Cell | 12 crystal + 8 ore | +80 fuel |

### Ship Upgrades (Planet Services tab)
| Upgrade | Cost | Effect |
|---|---|---|
| Hull Plating | Credits | +20 max hull |
| Fuel Tank | Credits | +20 max fuel |
| Engine Boost | Credits | +15% speed |
| Weapon Mod | Credits | +10 damage |

---

## Cockpit Interface (5 tabs)

1. **Bridge** — ship stats, XP bar, perk point count
2. **Captain** — perk tree, unlock with perk points
3. **Crafting** — instant-use recipes
4. **Inventory** — collected artifacts with descriptions and bonuses
5. **Map** — fog-of-war world map, explored trail, discovered planets, grid, origin marker

---

## Visual System

### Sprites (AI-generated, background-removed with rembg)
| Object | Sprite | Size |
|---|---|---|
| Player ship | `2026-03-15-ship-sprite.png` | 72px |
| Pirate | `2026-03-15-enemy-pirate.png` | 60px |
| Drone | `2026-03-15-drone.png` | 52px |
| Battleship | `2026-03-15-battleship.png` | 90px |
| Turret | `2026-03-15-turret.png` | 56px |
| Interceptor | `2026-03-15-interceptor.png` | 44px |

### Procedural Art (GDScript `_draw()`)
- Planets: colored circles with atmosphere ring and surface detail
- Stars: animated corona rays, multi-layer glow
- Black holes: rotating accretion disk rings, singularity pulse
- Space stations: cross-shaped with rotating body, solar panels, blinking nav lights
- Asteroids: irregular polygon shapes, color-coded by resource type
- Hazard asteroids: dark red with heat glow
- Loot orbs: blinking gold with credit label
- Bullets: cyan glow (player) / orange-red glow (enemy) with multi-layer halo

### Effects
- **Parallax starfield** — 3 layers (240 stars), different scroll speeds
- **Engine trail** — cyan fade-out trail when thrusting
- **Explosions** — EffectsManager (Node2D world-space draw)
- **Floating text** — XP/credit pickups, damage numbers
- **Screen shake** — on hull damage, scales with trauma level

---

## Architecture

### Key Scripts

| Script | Role |
|---|---|
| `game_state.gd` | Singleton — all game data, signals, roguelite split |
| `save_manager.gd` | JSON save/load to user data |
| `space_world.gd` | Main scene controller, camera, death handling |
| `sector_generator.gd` | Procedural spawn, biome system, safe distances |
| `hud.gd` | All HUD elements, joystick, fire toggle, action button |
| `cockpit.gd` | 5-tab captain interface |
| `planet_menu.gd` | 4-tab planet interface (quests, services, buildings, storage) |
| `station_menu.gd` | Simple dock services |
| `effects_manager.gd` | World-space explosions, sparks, floating text |
| `world_data.gd` | Static data — planet names, quest templates, artifact definitions |

### Critical WASM Rules
> These rules prevent silent crashes in the WebGL build:
- Never call `add_child()`, `queue_free()`, `hide()`, or `set_process()` from `_process()`, `_physics_process()`, or signal callbacks
- Use `call_deferred("method_name")` for all of the above
- Use explicit types on variables assigned from array indexing: `var x: Type = arr[i]` not `var x := arr[i]`
- All bullet spawning uses `call_deferred("_spawn_bullet", ...)` → `get_parent().add_child(bullet)`
- Death triggers via `call_deferred("on_player_death")` with `_dying` guard flag to prevent multi-hit death loops
- Enemy `take_damage()` is called from `bullet.gd` `_process()` — always use `call_deferred("_die")` / `call_deferred("_explode")`, never call directly
- Asteroid `mine()` must call `call_deferred("queue_free")` — otherwise Mine button stays visible permanently

### Mobile WebGL Input Rules
> Control/Button input is unreliable on mobile WebGL. Always use scene-level `_input()`:
- **Never** use `Button.pressed` signal for game controls — doesn't reliably fire on mobile WebGL
- **Never** use `Control._gui_input` override or `gui_input` signal for HUD game buttons — both `InputEventScreenTouch` AND `InputEventMouseButton` fire on a single tap, causing double-toggle
- **Always** handle game input in `_input()` at the Node/CanvasLayer level with position-based detection
- Fire zone pattern: `tap_pos.x > vp_size.x - 120 and tap_pos.y > vp_size.y - 120`
- Use a `_debounce: float` timer (0.3s) decremented in `_process()` to block duplicate events
- Exception: `virtual_joystick.gd` works with `_gui_input` because it tracks a `_touch_index` and only acts on the first press — same debounce logic manually

---

## Save Data

Saved to `user://savegame.json`:
- Captain XP and perks
- Credits
- Resources
- Hull / fuel
- Planet data (quests done, buildings, storage)
- Map discovered planets
- Artifacts collected

---

## Roadmap

### High Priority (Next Sprint)
- [ ] **Death screen** — session score formula: `credits + kills×15 + artifacts×150`
- [ ] **Zone difficulty scaling** — enemy stats scale with distance from origin
- [ ] **Raid events** — every 90s: WARNING → enemy wave spawns → reward on clear

### Medium Priority
- [ ] **Tutorial overlay** — first-launch only, 3 panels
- [ ] **Telegram score sharing** — share session score via bot
- [ ] **Gas clouds** — visual fog zones, slow movement 30%, hide enemies
- [ ] **Derelict ships** — board to scavenge loot, risky encounter
- [ ] **Biome visualization** on cockpit map (different colors per zone)

### Design Decisions Pending
- Should `artifacts_collected` persist across deaths like captain XP? (Currently resets)
- `lucky_find` perk needs artifact tier system in `world_data.gd`
- Captain classes (foundation in place, not yet exposed)
- Multiple weapon types for fire toggle system (shotgun, missile, laser)

---

## Dev Notes

### Deployment Pipeline
```bash
# 1. Export
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" web-export/index.html

# 2. Fix corrupt PNG (Godot bug)
python3 -c "import struct,zlib; ..."  # generates valid 1×1 index.png

# 3. Deploy to gh-pages worktree
cp web-export/* /tmp/gh-pages-deploy/
cd /tmp/gh-pages-deploy && git add -A && git commit -m "vN: ..." && git push

# 4. Update Telegram bot menu button URL
curl -s "https://api.telegram.org/bot.../setChatMenuButton" ...
```

### Bot
- Token: `8573291296:AAHgEBFidxMQNswUFuBSLn-r5kZKwxV-8Zs`
- Game URL pattern: `https://ichizh8.github.io/space-game-rt/?v=N`

### Local Project
- Path: `/Users/speek-c/space-game-rt/`
- gh-pages worktree: `/tmp/gh-pages-deploy`
- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`
- Export preset: `"Web"`, output: `web-export/index.html`
