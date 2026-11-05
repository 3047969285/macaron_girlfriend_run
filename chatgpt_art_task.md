# ChatGPT Art Generation Task - Macaron Girlfriend Run

## Project Overview
Flutter + Flame 2D side-scrolling platformer game (马卡龙女友跑酷). 
Pixel art style, cute/sweet macaron/dessert theme.
Target: GitHub Pages web deployment, landscape orientation.

Tile size: 48x48 pixels. Sprites should be crisp pixel art at 1x or 2x scale.

---

## World 1: 奶油草地 (Cream Meadow) — Song: 素颜 (Bare Face)
**Mood**: Soft morning light, gentle, pure, pastoral
**Colors**: Sky #FFF4EC → #DCEBFF, Ground #9FE8C0 / #6FCB9A, Accent pink blush
**Assets needed**:
- Parallax backgrounds (3 layers): soft pastel hills, floating clouds, distant cream-colored village
- Ground tiles: lush green grass with cream/vanilla flowers
- Platform tiles: fluffy cloud platforms, cream puff stepping stones
- Decorations: morning dew drops, small butterflies, vanilla flowers, dandelion puffs
- Enemies: cute pudding slimes, whipped cream blobs
- Boss: Giant Vanilla Cake Monster

---

## World 2: 草莓甜点 (Strawberry Desserts) — Song: 身骑白马 (White Horse)
**Mood**: Romantic, adventurous, dramatic with Chinese folk flair
**Colors**: Sky #FFD6E5 → #FFF0F5, Ground #FF9EBB / #E8789C, Accent lemon yellow
**Assets needed**:
- Parallax backgrounds: strawberry hills, candy cane gates, pink sunset clouds
- Ground tiles: strawberry jam terrain, wafer cookie platforms
- Platform tiles: macaron stepping stones, chocolate bridges
- Decorations: strawberry rain, heart sparkles, candy lanterns
- Enemies: angry strawberry soldiers, chocolate knights
- Boss: Strawberry Dragon (白马 White Horse theme)

---

## World 3: 薄荷汽水 (Mint Soda) — Song: 谁 (Who)
**Mood**: Mysterious, ethereal, questioning, dreamy underwater/bubble feel
**Colors**: Sky #D8FFF2 → #B8E0FF, Ground #7ED9C2 / #4FB89E, Accent sky blue
**Assets needed**:
- Parallax backgrounds: floating bubbles, mint-green jellyfish, underwater mint caves
- Ground tiles: crystal mint ice platforms, fizzy soda geysers
- Platform tiles: ice cube platforms, bubble platforms (semi-transparent)
- Decorations: rising bubbles, question mark sparkles, echo ripples
- Enemies: soda pop fish, mint ghost wisps
- Boss: Giant Bubble Phantom (mysterious, ethereal)

---

## World 4: 香芋星空 (Taro Starry Sky) — Song: 静悄悄 (Quietly)
**Mood**: Serene night, quiet, intimate, stargazing
**Colors**: Sky #2A1F4D → #6B5B95, Ground #B39DDB / #8571B3, Accent lilac
**Assets needed**:
- Parallax backgrounds: deep purple starfield, twinkling constellations, aurora borealis
- Ground tiles: purple taro cloud terrain, moonstone paths
- Platform tiles: floating star platforms, crescent moon bridges
- Decorations: fireflies, shooting stars, sleeping moon faces, star dust trails
- Enemies: shadow bats, sleepy star creatures, night mushrooms
- Boss: Midnight Taro Golem (slow, powerful, quiet menace)

---

## World 5: 柠檬沙滩 (Lemon Beach) — Song: 5:20AM
**Mood**: Dawn energy, warm sunrise, beach vibes, hopeful
**Colors**: Sky #FFC9A8 → #FFF0C8, Ground #FFE082 / #E6C35C, Accent mint green
**Assets needed**:
- Parallax backgrounds: sunrise over ocean, palm tree silhouettes, golden sand dunes
- Ground tiles: golden sand, lemon-yellow rock formations
- Platform tiles: coconut shell platforms, surfboard bridges, sandcastle towers
- Decorations: seagulls, sunrise rays, wave splashes, lemon slices
- Enemies: crab soldiers, sand worms, angry seagulls
- Boss: Lemon Kraken (giant tentacles emerging from golden sea)

---

## World 6: 玫瑰城堡 (Rose Castle) — Song: Lost (迷失玫瑰)
**Mood**: Grand finale, gothic romance, maze-like, bittersweet
**Colors**: Sky #E9C9E8 → #C9B8E8, Ground #E89AB5 / #C46F8E, Accent lilac
**Assets needed**:
- Parallax backgrounds: grand rose castle silhouette, thorny towers, stained glass windows
- Ground tiles: rose petal paths, marble castle floors
- Platform tiles: floating rose platforms, chandelier swings, spiral staircase pieces
- Decorations: falling rose petals, candle flames, broken mirrors, vine tendrils
- Enemies: thorn knights, rose golem guards, mirror phantoms
- Boss: Rose Queen (final boss, elegant and dangerous)

---

## Shared Assets (all worlds)
- **Player character**: Cute anime-style girlfriend, idle/run/jump/fall/duck animations (already have base sprites, may need refinement)
- **Collectibles**: Coins (macaron-shaped), hearts, power-up stars
- **Power-ups**: Speed boost (candy rocket), Shield (sugar dome), Gun (cream cannon)
- **UI elements**: Health hearts, score display, skill buttons (王者荣耀 style touch controls)
- **Particles**: Jump dust, landing impact, dash trail, death sparkle

## Technical Notes
- All sprites should be PNG with transparent backgrounds
- Tile sprites: 48x48 px (or 96x96 for 2x)
- Character sprites: ~64x64 base size
- Parallax layers: full screen width, seamlessly tileable horizontally
- Boss sprites: ~128x128 or ~192x192
- Keep file sizes small for web deployment
