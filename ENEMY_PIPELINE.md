# Enemy Pipeline

## Status Legend
- 🔜 Queued
- 🔧 In Development
- ✅ Shipped
- ❌ Cut

---

## v68 — Biomes + Difficulty Scaling + 4 New Enemies

### System Changes
- [ ] Zone difficulty scaling (HP/damage/speed × distance multiplier)
- [ ] Biome-aware enemy spawning in sector_generator
- [ ] Loot credit reward scales with zone

### New Enemy Types

| Enemy | Biome | Status | Notes |
|---|---|---|---|
| Void Sentinel | Deep Space | 🔧 v68 | Tanky, slow, heavy shots, stays at range |
| Sniper | Deep Space | 🔧 v68 | Long charge-up telegraph → fast single shot |
| Minelayer | Debris Field | 🔧 v68 | Drops proximity mines, creates no-go zones |
| Carrier | Asteroid Belt | 🔧 v68 | Spawns drones every 8s, must be priority-killed |
| Juggernaut | Deep Space | 🔜 v69 | Slow+tanky, charges/dashes, collision damage |
| Scrap Raider | Debris Field | 🔜 v69 | Fast pirate variant, high scrap drops |
| Leech | Nebula | 🔜 v70 | Attaches to ship, drains fuel |
| Phantom | Nebula | 🔜 v70 | Blinks on hit, homing missiles |
| Arc Cannon | Deep Space | 🔜 v70 | Mortar-style arcing projectiles |
| Graviton | Nebula/Deep Space | 🔜 v71 | No weapons, gravity pull mechanic |

---

## Biome Spawn Weights (v68)

| Biome | Spawn Table |
|---|---|
| MIXED | 30% pirate, 25% drone, 20% interceptor, 15% sniper, 10% carrier |
| ASTEROID_BELT | 50% pirate, 30% drone, 20% carrier |
| DEBRIS_FIELD | 40% interceptor, 35% minelayer, 25% pirate |
| DEEP_SPACE | 40% void_sentinel, 35% sniper, 25% pirate |
| NEBULA | 50% drone, 30% interceptor, 20% drone |

---

## Zone Difficulty Scaling (v68)

- Zone = floor(player_distance / 1500), capped at 5
- HP multiplier: 1.0 + zone × 0.35
- Damage multiplier: 1.0 + zone × 0.2
- Speed multiplier: 1.0 + zone × 0.1
- Credit reward multiplier: 1.0 + zone × 0.2

---

## v69 Planned

- Juggernaut: charge telegraph + dash attack
- Scrap Raider: reskin of enemy.gd with boosted speed + scrap drops
- More biome visual polish

## v70 Planned

- Leech: attach mechanic, joystick shake to remove
- Phantom: blink-on-hit, homing projectile type
- Arc Cannon: mortar/arcing projectile system

## v71 Planned

- Graviton: gravity field mechanic
- Possibly raid events system
- Derelict ships
