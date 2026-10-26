# Cornelia — Final Fantasy I (remake vertical slice)

A small, playable 3D remake slice of the opening of **Final Fantasy I**: the city of
Cornelia, its castle, the northern bridge and the two-floor **Chaos Shrine** beyond
it. Made with **Godot 4.7**.

The game is a vertical slice with exploration, city services and turn-based
**battles on the bridge and in the shrine**. The party has persistent gold,
inventory, HP, equipment, experience and spell charges; Cornelia's houses contain
an inn, weapon/armour/item shops and a clinic. The route runs from the castle gate,
across the northern bridge, through the shrine's key-locked door and up its stairs
to Garland — then back to the king with Princess Sarah. The king's post-rescue
audience ends with a scripted bridge-construction finale and the demo-complete
screen.

**Коротко по-русски.** Откройте `project.godot` в Godot 4.7 и нажмите F5. Партия
идёт по клеткам 2 м через `WASD`/стрелки, `E` — войти в здание, поговорить,
открыть услугу, сундук или дверь. `I` открывает снаряжение. На северном мосту и в
Святилище Хаоса с шансом начинаются пошаговые бои: партия справа, враги слева,
ряды «передний/задний», ход по ловкости, команды «Атака / Заклинание / Предмет /
Бегство». Белая и чёрная магия тратят заряды уровней, а не ману. В подземелье
нужно найти сундук с Ключом Хаоса, открыть им дверь, подняться на второй этаж и
победить Гарланда. После спасения Сары король говорит другую реплику, а затем
запускается сцена, где королевские рабочие завершают северный мост. Завершает демо
надпись «ДЕМО ЗАВЕРШЕНО». Победа даёт опыт и золото; поражение возвращает отряд к
последнему ночлегу.

![Cornelia overview](screenshots/00_cornelia_overview.png)

## Run it

1. Open `project.godot` in **Godot 4.7** (tested with 4.7.2).
2. Press **F5** to run the project.
3. The game starts immediately at the castle gate in Cornelia.

### Controls

| Input | Action |
| --- | --- |
| `W A S D` / arrow keys | Walk one 2 m grid cell (orthogonally) |
| `E` / `Enter` / `Space` | Enter a building, talk, open a service, buy/sell, confirm, continue dialogue |
| `I` | Open / close the **equipment** panel |
| `↑` / `↓` or `W` / `S` | Choose a shop item, a hero, equipment, a battle command or a target |
| `←` / `→` or `A` / `D` | Switch Buy/Sell in a shop; choose weapon/armour/row in equipment |
| `Esc` | Close a panel, or go back in battle |
| Window close | Quit |

The camera follows the leader with a fixed top-down angle. The three followers
trace the leader's path in a single-file train. The bottom-left wallet and the
HP values on the party cards remain visible in town, so service and equipment
results can be checked after leaving a house.

During battle the same arrows choose commands, targets, spells and items, `E`
confirms and `Esc` goes back. The battle has its own top-down camera and HUD.

## The route

The player starts at the gate of Cornelia Castle. The quest tracker points north:

1. Walk through the plaza, along the north road and through the **northern gate**.
2. Cross the bridge and reach its **far end**. The objective updates and a toast
   confirms it.
3. Return to the castle gate, press `E` to enter, and walk into the **throne room**.
4. Approach the king and press `E` to hear about Sarah and Garland.
5. At the far landing, find the purple-lit **Chaos Shrine** entrance. On the first
   floor, open the chest for the **Chaos Key**, then unlock the north door.
6. Climb the staircase to the second floor and defeat **Garland** at the altar.
7. Watch the short rescue scene with **Sarah**, return to the king and hear his new
   line.
8. The king's order starts the scripted **northern-bridge construction** finale.
   Workers hammer the last span into place; the demo ends on the
   **«ДЕМО ЗАВЕРШЕНО»** screen (`E` / `Esc` quits).

All six houses are also enterable round-trip; each door changes the location while
the same four heroes, their order, classes, HP, gold, inventory, equipment, spell
charges and experience are preserved. Crossing the bridge or walking through the
shrine can trigger a random battle; victory or escape returns the party to the same
cell, while defeat returns it to the last inn sleep.

## Services in the existing houses

Five of the six existing houses now contain a walk-up service counter with its own
sign. There are no extra NPCs: the counter itself is the interaction point.

| House | Service | What it does |
| --- | --- | --- |
| baker (north-east) | **Постоялый двор** | Sleeps the whole party for 30 G and fully heals all four heroes |
| herbalist (east) | **Лавка предметов** | Sells and buys potions, antidotes, tents and torches |
| smith (south-west) | **Лавка оружия** | Sells and buys swords, daggers, staffs and knuckles |
| weaver (north-west) | **Лавка брони** | Sells and buys leather, cloth, shields and bronze armour |
| elder (south) | **Клиника** | Heals one lost (HP 0) hero for 80 G; refuses with explicit text when gold is short |
| fisher (south-east) | private home | no service |

Starting gold (300 G), starting inventory, hero max HP, every price, service
location, item description and shop stock list live in `data/game.json` and
`data/items.json`. The wallet, inventory, hero HP and lost flags live only in
`GameState`.

A service panel is keyboard-driven: `↑/↓` selects, `←/→` switches shop mode,
`E` performs the transaction and `Esc` closes. Bridge battles can leave heroes lost
(HP 0); the clinic restores one such hero, while the inn restores the whole party
and refills all spell level charges.

## Equipment and bridge combat

### Equipment

Press `I` anywhere in town or a house to open the equipment panel. Every hero has
a **weapon** and **armour** slot plus a **front/back row** setting. Weapons and
armour bought in the shops appear in the bag; equipping moves an item from the bag
into the slot, and the previously equipped item returns to the bag. The derived
stats are shown in the panel and used everywhere:

- attack — physical damage;
- defence — physical damage reduction;
- agility — turn order and escape chance;
- magic — spell damage and healing.

The picker now favours real items rather than an empty slot: entering a slot selects
the first usable item, shows its description, count and a live **stat-change
comparison** against the currently equipped piece, and keeps **«Снять»** at the end
of the list. The equipped item and its bonuses are shown when the picker is closed,
and the panel uses clear W/S and A/D key hints. All item bonuses live in
`data/items.json`. Bare hands are valid; the starting party owns no gear and must buy
or find it. The row setting is also editable here.

### Bridge battles

Crossing the bridge checks a JSON encounter chance on every accepted step. A
successful check loads **`scenes/battle.tscn`** — a separate top-down battle set on
the same north bridge, with the party on the right and goblins on the left.

- Each side has front and back ranks. A back-row combatant deals **60%** damage and
  takes **50%** of incoming melee damage. These multipliers are in
  `data/combat.json`; the enemy AI is more likely to melee front-row heroes.
- Every round the turn order is rebuilt from living combatants sorted by effective
  agility, so equipment changes who acts first.
- Commands are **Атака / Заклинание / Предмет / Бегство**. Attack, damaging spells
  and healing spells choose a target.
- **White magic** (Lira) and **black magic** (the goblin shaman) consume a charge of
  the spell's level and school. There is no mana stat. Level charges refill at the
  inn and after a defeat return.
- **Items** are drawn from the party inventory: a potion is consumed on use and
  heals the chosen ally.
- Victory awards the sum of enemy XP and gold from JSON. Defeat shows the
  **«ПАРТИЯ ПОГИБЛА»** screen, then returns the party to the last inn sleep, fully
  healed with spell charges restored.
- Damage, healing, item use, escape chance, row multipliers, spells, enemies,
  encounter weights and rewards are all in `data/combat.json`; consumable behaviour
  is in `data/items.json`.
- **Battle readability** — an action banner announces every hero/enemy turn and
  attack/spell/item, combatants have billboard name labels, duplicate enemies get
  Roman suffixes (`Гоблин-налётчик I/II`), the chosen target gets a red battlefield
  ring, and fallen units change their field label, show a cross marker and become
  **«ПАЛ»/«ПОВЕРЖЕН»** in the status panels. The battle title has its own dark
  banner, and the command panel is narrower so the arena stays visible.

```json
"formulas": {
  "physical_damage": "(attack - defense * 0.55 + variance) * row_mult",
  "spell_damage": "(magic * 1.2 + spell_power - defense * 0.35 + variance) * row_mult",
  "heal": "spell_power + magic * 1.2 + variance"
},
"spells": {
  "holy_lance": {"school": "white", "level": 2, "type": "damage", "target": "enemy", "power": 24}
}
```

## The Chaos Shrine

The shrine entrance is the purple-lit stairwell on the eastern side of the far
bridge landing. It is a separate two-floor location with a visible staircase:

- **Floor one** — a large pillared hall. A chest on the west side contains the
  **Chaos Key**. The north door is locked: interacting without the key gives an
  explicit refusal and the door stays solid. With the key it swings open, keeps the
  key in the inventory, and enables the staircase behind it.
- **Floor two** — the altar room. The staircase down returns to floor one; the
  staircase up leads here. **Garland** stands before the altar.
- **Rare random battles** — both floors use the same battle scene/rules with a
  `0.05` / `0.04` chance per step and shrine-themed skeletons, wraiths and cultists.
  Shrine encounters use the separate top-down shrine arena rather than the bridge.
- **Garland** — a single boss with **380 HP**, strong physical attacks and black
  magic. Without the gear sold in Cornelia he is very hard; a well-equipped party can
  win the long fight. His arena is the same ritual-circle chamber.
- **Rescue** — after Garland falls, Sarah appears at the altar and a three-line
  scene confirms the rescue. The objective switches back to the king, and talking to
  him again returns a different epilogue line. The boss cannot be refought and Sarah
  remains in the altar room.

The shrine uses `data/world.json` for both rooms, shrines flags and interaction
positions, `data/combat.json` for its enemies/boss/arena, and `data/items.json` for
the Chaos Key. Both floors now have rune reliefs, sentinel obelisks, candle banks,
a chest alcove, a carved altar arch with a horned idol, red banners and drifting
dust.

## Finale: the northern bridge

The first time the player closes the king's post-rescue dialogue in the throne room,
the demo leaves exploration and loads **`scenes/ending.tscn`**. This is a separate,
non-interactive cinematic:

- royal workers hammer the unfinished central span of the northern bridge;
- a suspended final block descends into the gap, raises dust and completes the deck;
- the camera pulls back over the river, the far gate and the waiting party;
- captions explain the king's order and the completed crossing;
- the final card reads **«ДЕМО ЗАВЕРШЕНО» / «Спасибо за игру.»**, with `E`/`Esc` to
  quit.

The sequence is guarded by the `demo_ending_started` flag and sets `demo_complete`
only when the final title appears. Its captions are in `data/game.json`; the scene,
worker animation, hammering, suspension and camera are procedural.

## Implemented content

- **Cornelia town** — a cobbled plaza with a fountain, six enterable half-timbered
  houses, town walls with crenellations and corner towers, a castle exterior with a
  ceremonial south gate and a side postern.
- **Northern gate and bridge** — two gate towers, a raised portcullis, a stone bridge
  over an animated river, lanterns, a far landing, a "North Road" sign and the
  purple-lit stairwell into the Chaos Shrine.
- **Chaos Shrine** — two dark, pillared floors linked by a staircase; a treasure
  chest containing the Chaos Key, a key-locked door, a boss altar, Garland and Sarah.
- **Castle throne room** — a cutaway hall with marble floor, red carpet, columns,
  stained glass, braziers and the king.
- **Six house interiors** — shared data-driven cottage scene with per-house palette,
  bespoke service counters and props (hearth, herbs, fishing nets, loom, books,
  forge, inn keys, weapon racks, armour stand, clinic cot).
- **Services** — persistent gold, inventory and hero HP; an inn that fully heals
  all four and restores spell charges; three buy/sell shops with lists, prices and
  owned counts; and a clinic for one lost hero with an explicit insufficient-gold
  refusal.
- **Equipment** — weapon/armour slots, front/back row, per-item stat bonuses,
  derived attack/defence/agility/magic, and a full keyboard equipment panel (`I`)
  with a real-item-first picker, equipped detail, live stat comparison and an
  end-of-list unequip option.
- **Bridge and shrine battles** — a separate top-down battle scene with arena themes,
  four party heroes against goblins, skeletons and cultists, two ranks per side,
  agility turn order, four commands, target selection, level-charge white/black
  magic, inventory potions, escape, XP/gold rewards, defeat screen and last-rest
  recovery.
- **Battle presentation** — per-unit name labels, unique names for duplicate
  enemies, an action banner, a red target ring, fallen crosses and **ПАЛ/ПОВЕРЖЕН**
  status panels.
- **Boss and rescue** — Garland's 380-HP boss fight, a three-line Sarah rescue scene,
  a changed king epilogue and persistent shrine flags.
- **Finale** — a scripted royal bridge-construction cutscene with animated workers,
  a descending final span, a camera pull-back and the **«ДЕМО ЗАВЕРШЕНО»** card.
- **Party** — exactly four heroes: warrior, thief, monk and white mage. Distinct
  procedural silhouettes, idle breathing, a walking cycle, a single-file follow and
  per-hero HP on the HUD.
- **NPCs** — exactly three interactive NPCs with one line each: the castle guard,
  the resident and the king. Garland and Sarah are boss/cutscene actors in the
  shrine, and the five royal workers exist only in the non-interactive finale; none
  of them are world NPCs. The king explains that Garland took Princess Sarah and has
  a different line after her rescue.
- **UI** — party cards with HP, quest objective, persistent wallet/bag panel,
  location title cards, equipment panel, typewriter dialogue with a portrait
  monogram, service panels for the inn/shops/clinic, a dedicated battle HUD with
  turn order and combat log, interaction prompts, toasts and fade transitions.
- **Environmental detail** — chimney smoke and flower baskets in Cornelia, fireflies,
  rune reliefs, sentinel obelisks, candle banks and drifting dust in the shrine, and
  a carved idol-arch behind Garland's altar.
- **World collision** — walls, house bodies, castle masses, service counters, the
  fountain, props and river water are impassable. The grid itself is never drawn.

## Architecture

The project keeps mutable party state in exactly one object and keeps gameplay
tuning/content in JSON.

```
project.godot
data/
  game.json          movement, camera, UI timings, roster, stats, rows, charges, gold, finale text
  world.json         locations, spawns, NPCs, doors, houses, services, shrine, bridge, zones
  dialogue.json      NPC lines, king's alternate line, Sarah rescue cutscene
  items.json         item stats, equipment bonuses, Chaos Key, prices, stock, services
  combat.json        formulas, spells, enemies, shrine boss, encounters, arenas, UI copy
scripts/
  game_state.gd      autoload: the only mutable party / quest / combat state object
  main.gd            persistent host: location swap, fade flow, interactions, battles, story, finale
  party_rig.gd       persistent four-hero visual rig and grid movement
  character_visual.gd procedural hero, NPC, worker, goblin, shrine and boss models
  camera_rig.gd      fixed-angle follow camera with per-location framing
  battle/            battle unit, battle scene, battle HUD
  ending/            bridge-construction cinematic, worker animation, demo-complete UI
  world/             town, throne room, house and Chaos Shrine builders + location base
  ui/                HUD, equipment, story dialogue, class icons, services, title cards
shaders/             cobblestone, grass, water, marble, vignette
scenes/main.tscn     exploration entry scene
scenes/battle.tscn   separate top-down battle scene (bridge and shrine arenas)
scenes/ending.tscn   closing bridge-construction cinematic
tests/               acceptance, houses, services, equipment, battle and dungeon suites
tools/               exploration, battle, equipment, magic, shrine and finale screenshot tours
screenshots/
```

Key invariants:

- **One state object.** `GameState` owns `party` (including HP/lost, row,
  equipment and spell charges), `gold`, `experience`, `inventory`, the last-rest
  checkpoint, encounter state, the leader cell, path trail, location/spawn and quest
  flags. `PartyRig`, the HUD and the battle scene only present it.
- **No party reload on exploration scene changes.** `GameMain` swaps only the
  contents of `WorldHost`. The `PartyRig` and its four `CharacterVisual` nodes stay
  alive. The battle scene creates temporary presentation actors, but HP, equipment,
  inventory and spell charges still come from `GameState`.
- **Data-driven world and combat.** Locations, house variants, service links, shrine
  rooms, spawn formations, NPCs, interactions and objective zones are read from
  `data/world.json`. Movement, camera, roster, stats, rows, spell slots and starting
  gold are in `data/game.json`; items, equipment bonuses, the Chaos Key, all prices,
  stock lists and service definitions are in `data/items.json`. Formulas, spells,
  enemies, shrine encounters/boss, row multipliers, arena framing and rewards are in
  `data/combat.json`.
- **Persistent story state.** Chest, door, Garland and rescue states are flags in
  `GameState`; the key is an inventory item. The rescue cutscene is data in
  `dialogue.json` and is played by the shared story dialogue panel.
- **Grid movement without visible tiles.** Cells are 2 m; each accepted input moves
  exactly one cell. Walkability is checked with a physics shape query at the target
  cell, not by drawing a grid.
- **No external art.** Geometry, materials and shaders are generated in code, so the
  project has no missing asset references.

## Verification

The main acceptance test is a headless one-run traversal using the same collision
checks and `GameState` commits as normal movement:

```powershell
godot --headless --path . res://tests/acceptance.tscn
```

Last run: **43/43 checks passed** — keyboard movement, castle gate → far end of the
bridge → back to the gate → throne room → king dialogue.

The six-house round-trip test verifies that every house is enterable, maps to the
correct interior variant, returns to the correct town spawn and never rebuilds the
party:

```powershell
godot --headless --path . res://tests/houses.tscn
```

Last run: **72/72 checks passed**.

The services acceptance test covers the exact requested loop and all extra service
behaviour — enter a house, buy a potion, spend gold, rest at the inn, walk back to
the plaza and read the same gold and potion numbers from the persistent HUD:

```powershell
godot --headless --path . res://tests/services.tscn
```

Last run: **90/90 checks passed** — starting gold from JSON, house entry does not
reset state, keyboard shop navigation, item shop buy, all four healed by the inn,
wallet on the plaza shows `245 G` / `Зелье ×1`, all three shops
listing/buying/selling, and the clinic's insufficient-gold refusal followed by a
successful paid heal.

The equipment suite verifies that bought gear moves into a slot, changes derived
stats, swaps back into the bag, and that the row can be toggled:

```powershell
godot --headless --path . res://tests/equipment.tscn
```

Last run: **39/39 checks passed** — the new picker defaults to a real item, previews
the stat change, explains unequip, and still swaps/returns gear correctly.

The battle suite covers the complete bridge encounter loop:

```powershell
godot --headless --path . res://tests/battle.tscn
```

Last run: **54/54 checks passed** — equipment stats in battle, turn order by
agility, unique names for duplicate enemies, 3D name labels, the action banner,
target-ring visibility, fallen/revived field markers, real keyboard menu routing,
front/back damage, white level-2 charge consumption, black enemy charge consumption,
potion consumption, victory XP/gold, flee, defeat screen, last-rest recovery, and
Main triggering a battle from a bridge step.

The dungeon suite covers the complete Chaos Shrine route and the finale:

```powershell
godot --headless --path . res://tests/dungeon.tscn
```

Last run: **60/60 checks passed** — far-bridge entrance, two floors, rare shrine
encounters and shrine arena, locked door refusal, Chaos Key chest, unlock, disabled
stairs, staircase climb, Garland boss context/HP, forced victory screen, Sarah scene,
rescue flag/objective, king's different line, Sarah persistence, no boss refight,
the stairs down, the exit back to the far landing, the bridge-construction finale,
its workers, the hidden exploration HUD, the delayed `demo_complete` flag and the
**«ДЕМО ЗАВЕРШЕНО»** title.

All six suites: **358/358 checks passed**.

A development screenshot tour can be rendered with the installed Godot binary:

```powershell
godot --path . res://tools/capture_scene.tscn --resolution 1600x900
godot --path . res://tools/capture_battle.tscn --resolution 1600x900
godot --path . res://tools/capture_equipment.tscn --resolution 1600x900
godot --path . res://tools/capture_magic.tscn --resolution 1600x900
godot --path . res://tools/capture_battle_endings.tscn --resolution 1600x900
godot --path . res://tools/capture_shrine.tscn --resolution 1600x900
godot --path . res://tools/capture_ending.tscn --resolution 1600x900
godot --path . res://tools/capture_battle_states.tscn --resolution 1600x900
```

## Screenshots

| | |
| --- | --- |
| ![Castle gate](screenshots/01_cornelia_castle_gate.png) | ![Cornelia plaza](screenshots/02_cornelia_plaza.png) |
| ![North bridge](screenshots/03_north_bridge.png) | ![Far bridge](screenshots/04_far_bridge.png) |
| ![Throne room](screenshots/05_throne_room.png) | ![King audience](screenshots/06_king_audience.png) |
| ![Inn service](screenshots/08_inn_service.png) | ![Item shop](screenshots/09_item_shop.png) |
| ![Equipment](screenshots/12_equipment.png) | ![White magic](screenshots/13_white_magic.png) |
| ![Bridge battle](screenshots/11_bridge_battle.png) | ![Plaza after services](screenshots/10_plaza_after_services.png) |
| ![Shrine floor one](screenshots/16_shrine_floor1.png) | ![Garland's altar](screenshots/17_shrine_boss_room.png) |
| ![Garland battle](screenshots/18_garland_battle.png) | ![Sarah rescue](screenshots/19_sarah_rescue.png) |
| ![Bridge construction](screenshots/20_bridge_construction.png) | ![Demo complete](screenshots/21_demo_complete.png) |
| ![Target selection](screenshots/22_battle_target.png) | ![Fallen hero](screenshots/23_battle_fallen.png) |
| ![Equipment choice](screenshots/24_equipment_choice.png) | ![Victory](screenshots/14_victory.png) |
| ![Party defeated](screenshots/15_party_defeated.png) | ![House interior](screenshots/07_house_interior.png) |
