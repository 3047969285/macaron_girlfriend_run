import 'package:macaron_girlfriend_run/data/game_models.dart';

/// 99 关中文关卡名（九个世界都按配的歌曲气质命名）
class LevelNames {
  LevelNames._();

  static const List<List<String>> _byWorld = [
    [
      '晨雾小径',
      '清水湾',
      '素净坡',
      '白纱河堤',
      '露珠高台',
      '淡妆峡谷',
      '微光桥',
      '花影田',
      '浅色滑轨',
      '晨曦高塔',
      '素颜之心',
    ],
    [
      '马蹄台阶',
      '白鬃洞穴',
      '缰绳弹跳',
      '马鞍断桥',
      '云驹河流',
      '长鞭螺旋',
      '银蹄高台',
      '追风环',
      '草原谷',
      '踏雪之巅',
      '白马城堡',
    ],
    [
      '回声入口',
      '问号喷泉',
      '迷雾滑道',
      '影子气泡',
      '路灯跳台',
      '回眸峡谷',
      '空白隧道',
      '疑问风暴',
      '倒影平台',
      '无名高塔',
      '答案之心',
    ],
    [
      '静夜星门',
      '轻声台阶',
      '屏息浮岛',
      '月影断桥',
      '萤火平台',
      '无声回廊',
      '流星滑道',
      '安眠高台',
      '耳语之桥',
      '星尘之巅',
      '静夜王座',
    ],
    [
      '破晓海岸',
      '闹钟弹跳',
      '晨潮平台',
      '日出跳台',
      '第一缕光',
      '早班高堤',
      '海风滑道',
      '灯塔之桥',
      '金色沙堡',
      '黎明之巅',
      '二十分灯塔',
    ],
    [
      '迷途门廊',
      '回旋台阶',
      '断线平台',
      '荆棘回廊',
      '雾中塔楼',
      '花瓣断桥',
      '失落大厅',
      '迷宫高台',
      '指路之桥',
      '归途尖塔',
      '找回之心',
    ],
    [
      '蓝雾入口',
      '迷路跳台',
      '回声瀑布',
      '浆果断桥',
      '失途回廊',
      '蓝风高台',
      '水晶洞穴',
      '指南之桥',
      '云杉之巅',
      '归途王座',
      '蓝莓之心',
    ],
    [
      '追风矿口',
      '矿车奔驰',
      '马蹄跳台',
      '琥珀平台',
      '长鬃回廊',
      '焦糖高台',
      '晶矿断桥',
      '缰绳之桥',
      '黄金矿脉',
      '熔炉之巅',
      '追风之心',
    ],
    [
      '素面入口',
      '清晨台阶',
      '糖果浮岛',
      '淡色平台',
      '双星断桥',
      '素净回廊',
      '马卡龙塔',
      '彩虹高台',
      '云端之桥',
      '永恒之巅',
      '素颜终章',
    ],
  ];

  /// 获取关卡显示名
  static String of(int world, int level) {
    final w = world.clamp(0, GameConstants.worldCount - 1);
    if (level == GameConstants.depthLevelIndex) {
      return '歌曲深处';
    }
    final l = level.clamp(0, GameConstants.levelsPerWorld - 1);
    return _byWorld[w][l];
  }

  /// 完整标题 世界-关卡名
  static String fullTitle(int world, int level) {
    final worldName = WorldCatalog.paletteOf(world).displayName;
    return '$worldName · ${of(world, level)}';
  }
}
