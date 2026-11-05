import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/data/song_profile.dart';

enum SongWorldTheme {
  firstLove('心意', '心意守护', Color(0xFFEA7896), Color(0xFF815568)),
  whiteHorse('马蹄印', '白马疾行', Color(0xFFCE9B57), Color(0xFF76513B)),
  reflection('镜片', '倒影护盾', Color(0xFF79C8CE), Color(0xFF426D83)),
  quietLove('花瓣', '花瓣相伴', Color(0xFFC996D9), Color(0xFF66517E)),
  dawn('时间印记', '留住时光', Color(0xFFE6B852), Color(0xFF8B6650)),
  lost('路灯之光', '归路指引', Color(0xFF8CA5DD), Color(0xFF424B72));

  const SongWorldTheme(
    this.collectibleName,
    this.rewardName,
    this.light,
    this.dark,
  );

  final String collectibleName;
  final String rewardName;
  final Color light;
  final Color dark;

  String get rewardDescription => switch (this) {
    firstLove => '收集 8 个心意，获得短暂守护',
    whiteHorse => '收集 8 个马蹄印，刷新闪冲',
    reflection => '收集 8 片镜片，刷新护盾',
    quietLove => '收集 8 片花瓣，短暂吸引附近的花瓣',
    dawn => '收集 8 个时间印记，恢复 2 秒',
    lost => '收集 8 盏路灯之光，刷新糖线',
  };

  static SongWorldTheme forWorld(int world) =>
      values[SongProfile.songIndexOf(world)];
}
