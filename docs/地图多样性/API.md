# 接口文档：地图多样性（场景组合）

需求见 [PRD.md](PRD.md)（S1–S8）。测试：`test/level_scenes_test.dart`。

## 1. 新文件 `lib/data/level_scenes.dart`

```dart
enum SceneKind { staircase, archipelago, tower, skyBridge, ziggurat, valley, cloudRoom, hangingGarden, coinWave }

/// 一个已放置的场景。坐标是最终关卡行数据里的绝对 (列, 行)。
class PlacedScene {
  const PlacedScene({required this.kind, required this.x, required this.width, required this.mirrored, required this.cells});
  final SceneKind kind;
  final int x;            // 占地左端列（含）
  final int width;        // 占地列数（含全部 cells 的列范围）
  final bool mirrored;
  final Map<(int, int), String> cells; // (列, 行) -> '=' | '?' | 'C' | 'M'，只含本场景写入的格子
}

class SceneResult {
  const SceneResult(this.rows, this.scenes);
  final List<String> rows;
  final List<PlacedScene> scenes; // 按 x 从左到右
}

class LevelScenes {
  LevelScenes._();

  /// 权重表见 PRD 第 3 节，下标 = world，列 = SceneKind.index。
  static const List<List<int>> kindWeights = [...];

  /// clamp(width ~/ 30, 4, 14)
  static int plannedCount(int width);

  /// rows 是已含天空层的关卡行；地面站立行 g = rows.length - 3。
  /// 确定性（种子 = world * 1009 + level * 37 + 11，场景 i 的随机数再加 i * 17）。
  /// Boss 关（level == GameConstants.levelsPerWorld - 1）也放，但避开 Boss 站位 ±14 列。
  static SceneResult compose(List<String> rows, int world, int level);
}
```

### 1.1 `compose` 的行为

1. 计划：公开 `static List<SceneKind> planKinds(int world, int level)`，数量 = `plannedCount(widthOf(world, level))`，`widthOf = 140 + world * 18 + level * 18`。按 `kindWeights[world]` 做加权随机，约束：相邻不同；同一种 ≤ `ceil(count / 3)`；先保证不同种类数 ≥ `min(6, count)`（先各抽一个不重复的，再按权重补满，最后打乱并消除相邻重复）。level > 0 时，与 `planKinds(world, level - 1)` 按位置对齐后种类相同的比例要 ≤ 50%，否则换盐（种子 + 1000 × 次数）重抽，最多 20 次。
2. 放置：把 `[18, width - 22]` 平分成 count 段，场景 i 的目标列 = 第 i 段中点 ± 3（随机）；从目标列向左右各 `segmentWidth ~/ 2` 列内逐列尝试 `fits`，找到第一个就放；放不下就换成 `coinWave`，再不行就丢弃这个场景。同一场景的占地与相邻场景至少隔 2 列。
3. 随机变化：每种场景的长度、高度、间距、镜像、奖励摆法都由该场景的随机数决定，参数范围见 1.3。
4. 糖果与奖励预算：先数整关 `C`；场景放糖果只在总数 < 96 时放；每关场景糖果 ≤ 12；`M` ≤ 1；不放 `H`、`S` 和敌人。
5. 只写空格；返回的 `cells` 恰好是写入的全部格子。

### 1.2 公共规则

- **入口砖**：k=3（行 g−3）的砖所在列 c 必须通过 `entryOk(c)`：c±1 地面下两行都是 `#`；c−3…c+2 内没有坑起点（坑起点 = 坑格且左边一格不是坑）；c±2 内行 g 没有 `AEGRTLYJ`，c±3 内行 g 没有 `S`，c±3 内行 g−2 没有 `D`；c±2 内行 g−3 没有 `U/X/O/I`。k ≥ 4 的砖没有地面条件。
- **入口**：每个场景至少有一段 k=3 的砖，长度 1–3，所有入口砖都要通过 `entryOk`。能放 2–3 块就放 2–3 块，只有 1 个合格列时用 1 块踏脚石。配方里“入口 k=3 len N”按这个规则取 min(N, 合格连续列数)，至少 1。
- 高度范围：砖只能在 k=3（入口）或 k ∈ [7, 10]（行 g−3，或 g−10…g−7）；k=4–6 不放（全力起跳会顶到 k=6 的砖底）；行号不能小于 0（天空层之后行很多，普通 14 行关卡 g = 11，g−10 = 1）。
- **天空窗口**：在 `compose` 之前扫一遍，凡是行 < g 且为 `S` 的格子，其列 −3 到 +11 整段不放场景。
- **弹簧通道**：对每个地面行弹簧 `S`（列 c），列 c−3…c+9 内不放 k ≤ 7 的砖（k ≥ 8 的砖可以在上面）。
- 平台上的立足空间：每块砖上方两格（行−1、行−2）不能有别的砖（含自己场景里的）。
- 可达性约束：相邻两层之间，向上升 ≤ 3 格时最近两砖的水平间隔（空列数）≤ 3；升 4 格时间隔 ≤ 2；向下落时间隔 ≤ 4。下面的配方都满足。

### 1.3 配方（k = 距地面站立行的高度，`gap` = 两块砖之间空的列数）

写成“从入口往外”的顺序；镜像时整体左右翻转。`len` 为砖数。

- **staircase**：入口 k=3 len 2–3；gap 1–2 → k=7 len 2–3；gap 1–2 → k=9 len 2–3；50% 再 gap 1–2 → k=10 len 3–5。最顶一层上方放 1 个 `C`（或 `M`）。
- **archipelago**：入口 k=3 len 3；然后 3–5 座岛，len 2–4，岛的 k 在 7–10，首岛 k=7（gap 1–2），相邻岛 |Δk| ≤ 3，gap 1–3；最后一座 len ≥ 3，其中一块砖是 `?`。
- **tower**：入口 k=3 len 3；然后 3 层 len 2–3，k = 7, 9, 10：每层起点 = 上一层起点 + (奇数层 +3 / 偶数层 −2)，之字形上升，整体 ≤ 10 列；最顶层上放 `M` 或 `C`。上下两层不能在同一列叠住（站立空间）。
- **skyBridge**：入口 k=3 len 2；gap 1–2 → 小阶 k=7 len 2；gap 1 → 桥 k=8 或 9 len 10–16（可在中间空 1 列，但必须还剩一段 ≥ 8）；桥上方一排 `C`（≤ 5，起点和长度随机）；桥尾 gap 1 → 小阶 k=7 len 2；gap 1–2 → 出口 k=3 len 2。
- **ziggurat**：入口 k=3 len 3；gap 1–2；底层 k=7 len L（7–9）；其上 k=8 len L−2（居中）；k=9 len L−4（居中，≥ 1）。顶层上方放 `C` 或 `M`。
- **valley**：入口 k=3 len 2；gap 1–2 → 台 k=7 len 2；gap 1–2 → 台 k=10 len 3；gap 2–3 向下落到 → 谷底 k=7 len 3–5；gap 1–2 → 台 k=10 len 3；gap 2–3 向下落到 → 台 k=7 len 2；gap 1–2 → 出口 k=3 len 2。糖果放在谷底上方。
- **cloudRoom**：入口 k=3 len 3；gap 1–2 → 地板 k=7 len 8–10；屋顶 k=10 与地板重叠 ≥ 6 列（从地板第 2 列起，长度 L−2）。地板中央一块砖换成 `?`（从下面顶），地板上方放 `M` 或 `C`。（地板站立空间：k=8、k=9 两行必须是空的。）
- **hangingGarden**：入口 k=3 len 2；gap 1–2 → 台 k=7 len 2；gap 1 → 平台 k=8 len 10–14；平台下方（k=7，len 1）垂 2 根以上吊柱，距平台左端 ≥ 3 列，间隔 3–4 列；两根吊柱之间下方（k=5–6）可放 `C`（总数受预算限制）。
- **coinWave**：入口 k=3 len 3；gap 1–2 → 台 k=7 len 2；其后 8–12 列内摆 6–10 个 `C`，形状三选一：正弦波（行在 k=5..9 之间）、弧线、之字形；至少跨 3 行；`C` 只放空格，不要求站立。


## 2. `lib/data/level_catalog.dart`

```dart
/// 不含场景的关卡（含天空层），测试用。深渊关与 load 一致。
static LevelData loadBase(int worldIndex, int levelIndex);

/// 该关放置的场景（深渊关返回空列表）。
static List<PlacedScene> scenesOf(int worldIndex, int levelIndex);

static LevelData load(int worldIndex, int levelIndex); // 行数据 = _addSkyLayer 之后再 LevelScenes.compose 的结果
```

- 为避免重复计算，`LevelCatalog` 里用一个 `Map<int, SceneResult>`（键 = world * 100 + level）缓存 compose 结果；`loadBase` 不缓存也行。
- 其余生成函数一律不改。

## 3. 测试对象

- `test/level_scenes_test.dart`：S1–S7（见文件）。
- `test/level_catalog_test.dart` 的 “solid platforms stay in reachable band” 改为：带外的 `=`/`?` 必须在 `LevelCatalog.scenesOf` 返回的 cells 里。
