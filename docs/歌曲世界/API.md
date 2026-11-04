# 接口文档：歌曲世界

选关展示不新增外部接口，读取 `SongProfile.of(world)` 和已有存档星级；不改变关卡、存档或游戏输入接口。

需求见 [PRD.md](PRD.md)（W1–W7）。测试：`test/song_world_test.dart`，并调整 `test/level_scenes_test.dart` 里与新行为有关的阈值。

## 1. 新文件 `lib/data/song_profile.dart`

```dart
class SongProfile {
  const SongProfile({required this.title, required this.bpm, required this.energy, required this.motif});
  final String title;
  final double bpm;
  final List<double> energy; // 32 点，0..1
  final List<(int, int)> motif; // 糖果造型：(dx, dk)，dx 从 0 起向右，dk 从 0 起向上（0 = 最底一行）

  /// 世界 0–8 → 歌下标 0–5。音频播放（AudioService）和地图共用这一份。
  static const List<int> worldSongs = [0, 1, 2, 3, 4, 5, 5, 1, 0];
  static const List<SongProfile> songs = [...]; // 6 首，顺序同 AudioService.songs
  static int songIndexOf(int world);          // world 夹紧到 0..8
  static SongProfile of(int world);

  /// 一小节（4 拍）在关卡里的格数：clamp((1840 / bpm).round(), 12, 24)。
  static int barTiles(int world);

  /// 第 level 关（0..10）窗口的起点：level / 10 * 0.5；窗口长度 0.5。
  static double windowStart(int level);

  /// 第 level 关内横向进度 t（0..1，夹紧）处的响度：曲线位置 p = windowStart(level) + t * 0.5（0..1），第 k 个点在 p = k / 31 处，对相邻两点线性插值。
  static double levelEnergyAt(int world, int level, double t);
}
```

- `AudioService._worldSongs` 改为引用 `SongProfile.worldSongs`（删除重复的常量）；`AudioService.songs` 的顺序和歌名不变。
- 6 首歌的数据（速度、32 点曲线）见 `test/song_world_test.dart` 顶部的常量，实现里照抄同样的数值（曲线数据由原曲离线分析得出）。糖果造型见下。

## 2. 糖果造型模板（5 行 × 5 列，上面一行 = dk 4，`C` = 糖果）

```
素颜（心形）      身骑白马（马蹄）   谁（问号）        静悄悄（月牙）    5点20AM（钟面）   Lost（箭头）
.C.C.            .CCC.            .CCC.            .CC..            ..C..            ..C..
C...C            C...C            ....C            C....            .C.C.            ...C.
.C.C.            C...C            ..CC.            C....            C.C.C            CCCCC
..C..            C...C            .....            C....            .C.C.            ...C.
.....            .....            ..C..            .CC..            ..C..            ..C..
```

`motif` 列表里按“行从上到下、列从左到右”给出每个 `C` 的 `(dx, dk)`，`dk = 4 − 行号`。

## 3. `lib/data/level_scenes.dart` 的改动

```dart
class PlacedScene {
  // 新增，默认 false
  final bool climax; // 本关响度最高点最近的场景
  final bool motif;  // 糖果波摆成了歌的标志造型
}

class LevelScenes {
  /// 种类的“响度分”：staircase .7, archipelago .3, tower 1.0, skyBridge .4, ziggurat .9, valley .5, cloudRoom .8, hangingGarden .3, coinWave .1
  static const List<double> kindLoudness = [...]; // 顺序同 SceneKind.values
}
```

### 3.1 规划（`planKinds`）
- 原来的随机计划保持不变（数量、相邻不重复、每种次数上限、与上一关对齐相同比例 ≤ 50%）。另外每关计划里至少有一个 `coinWave`（原计划里没有就把出现次数最多的那种换掉一个），这样每个世界都能摆出歌的标志造型。
- 在检查这些约束**之前**，按位置做一次“响度匹配”：先算每个场景槽位的响度 `slotEnergy[i]`（见 3.2 的槽位位置），把计划里的种类按响度分从低到高排序，与槽位按响度从低到高一一对应；为避免整齐划一，匹配前给每个槽位的响度加上 ±0.1 的随机抖动（用该关种子）。若匹配后违反相邻不重复，沿用原来的“换盐重抽”。

### 3.2 放置（`_composeOnce`）
1. 槽位位置：在 `[lo, hi]`（`lo = 18`，`hi = width − 22`）上按权重 `0.15 + levelEnergyAt(world, level, (x − lo) / (hi − lo))` 做逆累积分布，第 i 个槽位取累积量 `(i + 0.5) / n` 处的列；再吸附到最近的小节线（`lo + k × barTiles(world)`），夹在 `[lo, hi]`；与前一个槽位至少隔开 `barTiles ~/ 2` 列（否则往右顺延）。
2. 搜索顺序：先试吸附后的列 ±2，再用原来的 `±seg/2` 搜索。其余逻辑（回退糖果波、第二轮空隙重放、种类不足时补种类、预算、盐重抽）保持不变。
3. 高潮：放置完成后，找出全关 `[lo, hi]` 内响度最高的列 `peak`；离它最近的场景标为 `climax`。若该场景的最高砖行 > g − 9（k < 9），尝试把它换成 `tower`、`ziggurat`、`cloudRoom` 中第一个能放下的；都放不下才保留原样（测试要求 k ≥ 9，所以实现要尽量放下）。
4. 糖果波的造型：`_coinWave` 里以 70%（用该场景的随机数）选歌的造型：把 `motif` 模板放在 `s + 3` 起、dk 0 对应 k=5 的位置（即 k = 5 + dk），随机镜像；糖果数不够时回退到原来的三种波形。`PlacedScene.motif` 记录是否用了造型。糖果预算规则不变（每关场景糖果 ≤ 12，总数 ≤ 96）。

## 4. 不变

- 敌人、机关、技能、天空层、深渊关、地面主路线。
- `LevelScenes.compose` 的签名、`LevelCatalog.load / loadBase / scenesOf` 的签名。
