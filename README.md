# Reyrey

A 2D platformer-adventure set in a grimdark medieval world, built with a high-fidelity, smooth pixel-stylized art direction that marries classic 16/32-bit side-scrolling precision with an atmospheric, weathered aesthetic.

Reynauld — a knight of House Valecourt — follows the trail of a wandering star across a decaying world, gathering ancient Scriptures that grant new movement abilities and Star Shrines that expand his reserves of Mana and Stamina, on the way to whatever waits at the top of the Tower.

Inspired by *Hollow Knight* and *Celeste*, the project is built around movement, exploration, progression, and platforming challenge and combat difficulty.

Built solo — programming, systems, and level design — in **Godot 4 / GDScript**, and sprite design and animation in **Libresprite**

---

## Table of Contents
- [Controls](#controls)
- [Features](#features)
- [Architecture & Technical Design](#architecture--technical-design)
- [Current Development Status](#current-development-status)
- [Roadmap](#roadmap)
- [Tech Stack](#tech-stack)
- [Credits](#credits)

---

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move Left / Right | `A`/`D`, Arrow Keys | Left Stick |
| Jump / Double Jump *(Spark Flame)* | `Space`, `Z` | Bottom Face Button (Cross / A / B) |
| Glide *(Vigil Wind)* — hold while falling | `Space`, `Z` | Bottom Face Button (Cross / A / B) |
| Dash *(Holy Lance)* / Dash Chain & Sprint *(Litany Step)* | `Shift`, `C` | Right Shoulder (R1 / RB) |
| Attack | `J`, `X`, Left Mouse | Left Face Button (Square / X / Y) |
| Upslash | `W`, Up Arrow | Left Stick Up |
| Pogo | `S`, Down Arrow | Left Stick Down |
| Ground Slam *(Martyr's Drop)* | `V`, `Ctrl` | Right Face Button (Circle / B / A) |
| Recall *(Star Anchor)* — press to place, press again to return | `R` | — |
| Interact | `E` | Left Face Button (Square / X / Y) |
| Inventory | `I` | — |
| Mix Potions | `P` | — |
| Potion Unlock Map | `O` | — |
| Use Potion | `F` | — |
| Pause | `Escape` | Start / Menu / + |

Wall Cling *(Wick Ember)* and Ledge Grab *(Censer Swing)* have no dedicated bind — they trigger contextually: hold toward a wall while airborne, or approach a ledge while falling.


## Features

### Movement — 8 Scriptures
| Scripture | Ability | What it does |
|---|---|---|
| Spark Flame | Double Jump | MP-fed second jump — empowered with a fire hitbox when MP is available, a weaker "smoke" jump otherwise |
| Holy Lance | Dash | MP-fed dash — empowered version grants invincibility and deals contact damage |
| Litany Step | Dash Chain | Lets a second dash cancel into the first dash's cooldown, at a Stamina cost. Allows sprinting |
| Martyr's Drop | Ground Slam | Airborne-only slam with an AoE damage radius, hitstop, and screen shake on impact |
| Vigil Wind | Glide | Slows fall speed while held |
| Wick Ember | Wall Cling | Stamina-gated wall slide/cling, enables wall jumps |
| Censer Swing | Ledge Grab | Raycast-detected; auto-climbs after a short delay if not manually released |
| Star Anchor | Recall | Places a return point, teleports back to it on a second press; snaps automatically if the player strays too far |

### Combat
- Three distinct attacks — Sword, Pogo, Upslash — each with its own hitbox, animation, and frame-window hit confirm
- Pogo yields a strong or weak bounce depending on whether Stamina was available, and can bounce off both enemies and pogoable environmental hazards
- Landing any hit temporarily boosts MP regeneration, rewarding aggression over passive waiting
- Spark flame, Martyr's drop, and Holy lance deal damage. Automatically consumes MP to deal extra damage.

### Resources
- HP / MP / Stamina, expanded permanently via Shrines (MP, Stamina) and Anvils (HP)
- Shader-driven glow HUD — MP and Stamina are glow-intensity only (no bar), HP uses a growing star-bar with a "damage trail" overlay that recedes slower than the main drain, plus a pulsing vignette at critical HP

### Progression & Saves
- JSON save/load across 4 slots, each with a pre-load summary (area, timestamp)
- Checkpoint system with rolling "last safe ground" history (see Architecture)
- **Primeval Star Potion** system: 3 category slots (Survival / Combat / Utility) unlocked progressively, with effects gated behind lifetime Star Fragment totals

### World Interactables
Locked doors, attack-switch doors, breakable walls, breakable floors (Ground Slam only), hidden walls, crumbling floors, falling platforms, one-way shortcuts (levers, ladders, bridges), and multi-wave enemy gauntlets that unlock a route on completion.

### Presentation
- Sequential-reveal ceremony screens for ability, shrine, anvil, and potion-slot claims (see Architecture)
- Per-room camera bounds, plus camera limit/reveal zones for boss arenas and set-piece vistas
- Threaded loading screen, area-name title cards on room entry
- Full inventory UI including a lore library (Scripture flavor text + shrine abandonment text)
- One-time contextual tutorials for movement, jump, attack, and each of the 8 abilities — triggered after a grace period of non-use rather than the instant an ability is unlocked

---

## Architecture & Technical Design

### GameState as a Single Source of Truth
All progression-relevant state — abilities, MP/Stamina/HP maximums, shrine/anvil claims, checkpoints, inventory flags — lives in the `GameState` autoload and nowhere else. The player's own `max_mp`, `mp`, and `max_stamina` are computed properties that read and write straight through to `GameState` rather than caching a local copy:

```gdscript
var mp: int:
    get: return GameState.current_mp
    set(value): GameState.current_mp = value
```

This exists because early versions let the player's stats drift out of sync with what actually got saved. With one authority, the HUD, the save file, and every ceremony screen are always reading the same number.

### Autoload Singletons + Signals
Every persistent system — GameState, SaveManager, AudioRouter, LoadingScreen, InventoryUI, PotionUI, AbilityTutorialUI, PotionTutorialUI — is an autoload, and they communicate through signals (`ability_claimed`, `star_fragments_changed`, `potion_mix_changed`, `modal_opened`) instead of direct references between scripts. Adding a new reactive system, like the HUD's key-item popup, means adding to a signal that already exists. It never requires editing the system that emits it.

### Greybox-First Level Development
Every room is built and made fully traversable on a single collision-authoritative `Greybox` TileMapLayer before any art layer goes in. Playtesting a room's platforming and flow is never blocked on the art pipeline, which is why "greybox Area 1" and "fully design Area 1" show up as separate, sequential milestones rather than one combined pass.

### Physics Layer Hygiene
Only `Greybox` carries collision. The `64x64`, `64x64BG`, and `64x64Design` tile layers are purely visual. Every hitbox, hurtbox, and interactable is assigned to one the explicit collision layers (Terrain, Player, Attackable, Player Attack, Hurts Player, Interactable, Player Detection, Enemy Aggro), so an overlap check for "did the sword hit an enemy" can never accidentally also register "did the sword hit a wall."

### Soft-Respawn Instead of Full Room Reload
Enemies go inert on death and are restored in place by `GameState.soft_respawn_enemies()` when the player rests at a checkpoint, instead of the entire room scene being torn down and reinstantiated. Reloading the full scene on every death or checkpoint rest was an identified performance bottleneck once rooms began carrying real enemy counts and particle effects.

### Adjacent Room Preloading & Caching
Room transitions preload neighboring rooms ahead of time and cache previously visited ones, rather than instantiating a fresh scene from disk the moment the player crosses a gate. This is created in order to adress performance issues and long loading times when entering a new room, before this patch, room loading can take from 1000ms to 3000ms at worst. This fix made rooms transitions near instantaeneous.

### Finite State Machine Boss (Guiding Superstar)
The first boss runs on an explicit finite state machine rather than a tangle of booleans and timers, so mutually exclusive phases — idle/aggro, telegraph, attack, stagger, defeated — can't overlap in invalid ways, such as taking lethal damage mid-attack and still completing the attack's damage window. The architecture was built out as a dedicated pass before the boss itself was implemented, specifically so later bosses can reuse the same state/transition pattern instead of each one being written from scratch.

### Sequential-Reveal Ceremony Pattern
Ability, shrine, anvil, and potion-slot claim screens all share one pattern: every element — title, illustration, description, keybind, prompt — starts fully transparent, and each one only fades in after the previous element has finished fading in and held for a short beat. The "press to continue" prompt is always the *last* element revealed, and it's the only thing the accept-button check listens for, so mashing the confirm button can never skip content that hasn't been shown yet.

### Rolling "Safe Ground" History
The player script keeps a short rolling history of grounded positions and selects one guaranteed to be at least a fixed lag window old, so there's always real distance between a hazard respawn and whatever just caused it.

### Threaded Loading Screen
The `LoadingScreen` autoload uses Godot's threaded `ResourceLoader` so a loading overlay can display during scene swaps instead of a hard freeze frame on larger rooms.

---

## Current Development Status

**Complete**
- Tutorial room Area 0, Area 1  — fully designed, not just greyboxed
- Shrines 1 and 2
- All 8 movement abilities, full combat kit, HP/MP/Stamina systems
- Save/load across 4 slots, room transition + camera systems, checkpoint/respawn
- First boss (Guiding Superstar) — fully working, including its defeat sequence
- Inventory, potion system, audio system, every interactable type, every ability/shrine/anvil ceremony

**In progress**
- Area 2 greybox pass (A2R1 complete, A2R2 underway)

## Roadmap
- Greybox and design Areas 3–9 (8 areas remaining)
- Shrines 3–17
- Full sound pass
- Tower ending polish
- Remaining enemy placement, boss, and tuning across all areas

## Tech Stack
- Godot 4, GDScript
- 64×64px tile grid, single collision-authoritative Greybox layer per room
- Python (PIL, NumPy, SciPy, OpenCV) and LibreSprite for the sprite-processing pipeline
## Creator
- **Justine** — programming, systems design, level design, art & animation

## Attributions

## Asset Credits & Attribution

This game uses assets from the following creators. Thank you to all of them.

- **Kenney** — Various packs (backgrounds, input prompts, platformer art/tilesets, particles, UI). CC0 1.0. No attribution required. [kenney.nl](https://kenney.nl/)
- **CodeManu** — VFX Free Pack, Pixel Effects Pack. Public domain. [codemanu.itch.io](https://codemanu.itch.io/vfx-free-pack)
- **Oisougabo** — Free Platformer 16x16 + Background. Free for commercial/non-commercial use. [oisougabo.itch.io](https://oisougabo.itch.io/free-platformer-16x16)
- **Kartoy** — 32x32 Grimstone Platformer Tileset. Free for personal/commercial use. [kartoy.itch.io](https://kartoy.itch.io/32x32grimstone-platformer-tileset)
- **Szadiart** — Pixel Fantasy Caves, Background Desert Mountains, Pixel Castle 2D, Pixel Dark Forest. Free for personal/commercial use. [szadiart.itch.io](https://szadiart.itch.io/)
- **Incolgames** — Dungeon Platformer Tile Set Pixel Art. Free to use/modify. *(Original files excluded from public repo per creator's redistribution restriction.)* [incolgames.itch.io](https://incolgames.itch.io/dungeon-platformer-tile-set-pixel-art)
- **GandalfHardcore** — Free Pixel Art Sidescroller Asset Pack 32x32 Overworld. Free for commercial/non-commercial use. [gandalfhardcore.itch.io](https://gandalfhardcore.itch.io/free-pixel-art-sidescroller-asset-pack-32x32-overworld)
- **Pixel-boy / Sparklin Labs** — Superpowers Asset Packs. CC0 1.0. [superpowers-html5.com](http://superpowers-html5.com/)
- **Pimen** — Holy Spell Effect. Free for personal/commercial use; no resale/redistribution as standalone assets. [pimen.itch.io](https://pimen.itch.io/holy-spell-effect)
- **Cainos** — Pixel Art Platformer - Village Props. Free for personal/commercial use; no resale/redistribution as standalone assets. [cainos.itch.io](https://cainos.itch.io/pixel-art-platformer-village-props)
- **ApyrYon** — Free Visual Effects. Free for personal/commercial use; no resale/redistribution as standalone assets, no NFTs. [apyryon.itch.io](https://apyryon.itch.io/visual-effects)
- **Luis Zuno (Ansimuz)** — GothicVania Church. Assets are licensed under Creative Commons Zero (CC0) and may be used, modified, and redistributed freely for personal or commercial projects. [ansimuz.itch.io]/gothicvania-church-pack

### Music
- "Night Vigil" — Kevin MacLeod (incompetech.com), CC BY 4.0
- "Send for the Horses" — Kevin MacLeod (incompetech.com), CC BY 4.0
- "Hidden Past" — Kevin MacLeod (incompetech.com), CC BY 4.0

Please support these creators if you enjoy their work.
