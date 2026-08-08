import 'package:shared_preferences/shared_preferences.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/shop_catalog.dart';

/// 本地进度与设置存档
class SaveService {
  SaveService._();
  static final SaveService instance = SaveService._();

  static const _keyUnlocked = 'unlocked_level';
  static const _keyStars = 'stars_map';
  static const _keyBestScore = 'best_score_map';
  static const _keyFpsMode = 'fps_mode';
  static const _keyRole = 'player_role';
  static const _keySound = 'sound_on';
  static const _keyMusic = 'music_on';
  static const _keyHaptic = 'haptic_on';
  static const _keyTutorial = 'tutorial_done';
  static const _keyTotalCoins = 'total_coins';
  static const _keyTotalScore = 'total_score';
  static const _keyClears = 'clear_count';
  static const _keyEnemyKills = 'enemy_kills';
  static const _keyBossClears = 'boss_clears';
  static const _keyWallet = 'wallet_coins';
  static const _keyOwnedCosmetics = 'owned_cosmetics';
  static const _keyEquippedCosmetic = 'equipped_cosmetic';
  static const _keySoundVol = 'sound_volume';
  static const _keyMusicVol = 'music_volume';
  static const _keySeenAchievements = 'seen_achievements';
  static const _keyLastWorld = 'last_world';
  static const _keyLastLevel = 'last_level';
  static const _keyAllClearSeen = 'all_clear_seen';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (_prefs?.containsKey(_keyWallet) != true) {
      await _prefs?.setInt(_keyWallet, totalCoins);
    }
    final owned = ownedCosmeticIds;
    if (!owned.contains(ShopCatalog.defaultId)) {
      await _prefs?.setString(
        _keyOwnedCosmetics,
        _encodeSet({...owned, ShopCatalog.defaultId}),
      );
    }
  }

  int get unlockedGlobalIndex => _prefs?.getInt(_keyUnlocked) ?? 0;

  Future<void> unlockThrough(int globalIndex) async {
    final current = unlockedGlobalIndex;
    if (globalIndex > current) {
      await _prefs?.setInt(_keyUnlocked, globalIndex);
    }
  }

  int starsOf(int globalIndex) {
    final map = _decodeMap(_prefs?.getString(_keyStars) ?? '');
    return map[globalIndex] ?? 0;
  }

  Future<void> setStars(int globalIndex, int stars) async {
    final map = _decodeMap(_prefs?.getString(_keyStars) ?? '');
    final prev = map[globalIndex] ?? 0;
    if (stars > prev) {
      map[globalIndex] = stars.clamp(0, 3);
      await _prefs?.setString(_keyStars, _encodeMap(map));
    }
  }

  int bestScoreOf(int globalIndex) {
    final map = _decodeMap(_prefs?.getString(_keyBestScore) ?? '');
    return map[globalIndex] ?? 0;
  }

  Future<void> setBestScore(int globalIndex, int score) async {
    final map = _decodeMap(_prefs?.getString(_keyBestScore) ?? '');
    final prev = map[globalIndex] ?? 0;
    if (score > prev) {
      map[globalIndex] = score;
      await _prefs?.setString(_keyBestScore, _encodeMap(map));
    }
  }

  int get fpsMode => _prefs?.getInt(_keyFpsMode) ?? 0;

  Future<void> setFpsMode(int mode) async {
    await _prefs?.setInt(_keyFpsMode, mode.clamp(0, 3));
  }

  PlayerRole get playerRole {
    final v = _prefs?.getString(_keyRole);
    if (v == PlayerRole.boyfriend.name) {
      return PlayerRole.boyfriend;
    }
    return PlayerRole.girlfriend;
  }

  Future<void> setPlayerRole(PlayerRole role) async {
    await _prefs?.setString(_keyRole, role.name);
  }

  bool get soundEnabled => _prefs?.getBool(_keySound) ?? true;

  Future<void> setSoundEnabled(bool v) async {
    await _prefs?.setBool(_keySound, v);
  }

  bool get musicEnabled => _prefs?.getBool(_keyMusic) ?? true;

  Future<void> setMusicEnabled(bool v) async {
    await _prefs?.setBool(_keyMusic, v);
  }

  bool get hapticEnabled => _prefs?.getBool(_keyHaptic) ?? true;

  Future<void> setHapticEnabled(bool v) async {
    await _prefs?.setBool(_keyHaptic, v);
  }

  double get soundVolume =>
      (_prefs?.getDouble(_keySoundVol) ?? 0.88).clamp(0.0, 1.0);

  Future<void> setSoundVolume(double v) async {
    await _prefs?.setDouble(_keySoundVol, v.clamp(0.0, 1.0));
  }

  double get musicVolume =>
      (_prefs?.getDouble(_keyMusicVol) ?? 0.42).clamp(0.0, 1.0);

  Future<void> setMusicVolume(double v) async {
    await _prefs?.setDouble(_keyMusicVol, v.clamp(0.0, 1.0));
  }

  bool get tutorialDone => _prefs?.getBool(_keyTutorial) ?? false;

  Future<void> setTutorialDone() async {
    await _prefs?.setBool(_keyTutorial, true);
  }

  Future<void> resetTutorial() async {
    await _prefs?.setBool(_keyTutorial, false);
  }

  int get totalCoins => _prefs?.getInt(_keyTotalCoins) ?? 0;
  int get totalScore => _prefs?.getInt(_keyTotalScore) ?? 0;
  int get clearCount => _prefs?.getInt(_keyClears) ?? 0;
  int get enemyKills => _prefs?.getInt(_keyEnemyKills) ?? 0;
  int get bossClears => _prefs?.getInt(_keyBossClears) ?? 0;
  int get walletCoins => _prefs?.getInt(_keyWallet) ?? totalCoins;

  Future<void> addRunStats({
    required int coins,
    required int score,
    required int kills,
    required bool cleared,
    bool bossCleared = false,
  }) async {
    await _prefs?.setInt(_keyTotalCoins, totalCoins + coins);
    await _prefs?.setInt(_keyWallet, walletCoins + coins);
    await _prefs?.setInt(_keyTotalScore, totalScore + score);
    await _prefs?.setInt(_keyEnemyKills, enemyKills + kills);
    if (cleared) {
      await _prefs?.setInt(_keyClears, clearCount + 1);
    }
    if (bossCleared) {
      await _prefs?.setInt(_keyBossClears, bossClears + 1);
    }
  }

  /// 世界通关一次性糖果奖励
  Future<int> grantWorldClearBonus(int worldIndex) async {
    final key = 'world_clear_bonus_$worldIndex';
    if (_prefs?.getBool(key) == true) {
      return 0;
    }
    final bonus = 60 + worldIndex * 15;
    await _prefs?.setBool(key, true);
    await _prefs?.setInt(_keyWallet, walletCoins + bonus);
    return bonus;
  }

  Set<String> get ownedCosmeticIds {
    final raw = _prefs?.getString(_keyOwnedCosmetics) ?? ShopCatalog.defaultId;
    return _decodeSet(raw);
  }

  String get equippedCosmeticId =>
      _prefs?.getString(_keyEquippedCosmetic) ?? ShopCatalog.defaultId;

  Future<bool> purchaseCosmetic(String id) async {
    final item = ShopCatalog.of(id);
    final owned = ownedCosmeticIds;
    if (owned.contains(id)) {
      return true;
    }
    if (walletCoins < item.price) {
      return false;
    }
    await _prefs?.setInt(_keyWallet, walletCoins - item.price);
    owned.add(id);
    await _prefs?.setString(_keyOwnedCosmetics, _encodeSet(owned));
    return true;
  }

  Future<void> equipCosmetic(String id) async {
    if (!ownedCosmeticIds.contains(id)) {
      return;
    }
    await _prefs?.setString(_keyEquippedCosmetic, id);
  }

  Set<String> get seenAchievementIds {
    return _decodeSet(_prefs?.getString(_keySeenAchievements) ?? '');
  }

  Future<void> markAchievementsSeen(Iterable<String> ids) async {
    final next = {...seenAchievementIds, ...ids};
    await _prefs?.setString(_keySeenAchievements, _encodeSet(next));
  }

  /// 返回本轮新解锁的成就标题
  Future<List<AchievementItem>> takeNewlyUnlockedAchievements() async {
    final all = achievements();
    final seen = seenAchievementIds;
    final fresh = all.where((a) => a.unlocked && !seen.contains(a.title)).toList();
    if (fresh.isNotEmpty) {
      await markAchievementsSeen(fresh.map((e) => e.title));
    }
    return fresh;
  }

  int get lastWorldIndex => _prefs?.getInt(_keyLastWorld) ?? 0;
  int get lastLevelIndex => _prefs?.getInt(_keyLastLevel) ?? 0;

  Future<void> setLastPlayed(int world, int level) async {
    await _prefs?.setInt(_keyLastWorld, world);
    await _prefs?.setInt(_keyLastLevel, level);
  }

  bool get allClearCelebrated => _prefs?.getBool(_keyAllClearSeen) ?? false;

  Future<void> setAllClearCelebrated() async {
    await _prefs?.setBool(_keyAllClearSeen, true);
  }

  bool get isAllLevelsCleared =>
      unlockedGlobalIndex >= GameConstants.totalLevels;

  /// 清除进度保留音量与帧率设置
  Future<void> resetProgress() async {
    await _prefs?.remove(_keyUnlocked);
    await _prefs?.remove(_keyStars);
    await _prefs?.remove(_keyBestScore);
    await _prefs?.remove(_keyTotalCoins);
    await _prefs?.remove(_keyTotalScore);
    await _prefs?.remove(_keyClears);
    await _prefs?.remove(_keyEnemyKills);
    await _prefs?.remove(_keyBossClears);
    await _prefs?.remove(_keyWallet);
    await _prefs?.remove(_keyOwnedCosmetics);
    await _prefs?.remove(_keyEquippedCosmetic);
    await _prefs?.remove(_keySeenAchievements);
    await _prefs?.remove(_keyLastWorld);
    await _prefs?.remove(_keyLastLevel);
    await _prefs?.remove(_keyAllClearSeen);
    for (var w = 0; w < GameConstants.worldCount; w++) {
      await _prefs?.remove('world_clear_bonus_$w');
    }
    await _prefs?.setBool(_keyTutorial, false);
    await _prefs?.setString(_keyOwnedCosmetics, ShopCatalog.defaultId);
    await _prefs?.setString(_keyEquippedCosmetic, ShopCatalog.defaultId);
    await _prefs?.setInt(_keyWallet, 0);
  }

  int get totalStars {
    final map = _decodeMap(_prefs?.getString(_keyStars) ?? '');
    return map.values.fold<int>(0, (a, b) => a + b);
  }

  int get bestScoreOverall {
    final map = _decodeMap(_prefs?.getString(_keyBestScore) ?? '');
    if (map.isEmpty) {
      return 0;
    }
    return map.values.reduce((a, b) => a > b ? a : b);
  }

  /// 成就进度文案
  List<AchievementItem> achievements() {
    return [
      AchievementItem(
        title: '初出茅庐',
        desc: '通关任意 1 关',
        icon: '🌱',
        progress: clearCount.clamp(0, 1),
        target: 1,
      ),
      AchievementItem(
        title: '糖果收集者',
        desc: '累计收集 50 颗马卡龙',
        icon: '🍬',
        progress: totalCoins.clamp(0, 50),
        target: 50,
      ),
      AchievementItem(
        title: '甜妹战士',
        desc: '踩扁 20 只小怪',
        icon: '🥊',
        progress: enemyKills.clamp(0, 20),
        target: 20,
      ),
      AchievementItem(
        title: '星光满天',
        desc: '累计获得 30 星',
        icon: '⭐',
        progress: totalStars.clamp(0, 30),
        target: 30,
      ),
      AchievementItem(
        title: '世界旅人',
        desc: '解锁第 3 世界',
        icon: '🗺️',
        progress: (unlockedGlobalIndex >= GameConstants.levelsPerWorld * 2)
            ? 1
            : 0,
        target: 1,
      ),
      AchievementItem(
        title: '满分挑战',
        desc: '任意关卡拿到 3 星',
        icon: '👑',
        progress: _hasTripleStar() ? 1 : 0,
        target: 1,
      ),
      AchievementItem(
        title: '时尚达人',
        desc: '购买任意 1 件外观',
        icon: '👗',
        progress: (ownedCosmeticIds.length > 1) ? 1 : 0,
        target: 1,
      ),
      AchievementItem(
        title: '蜜月终章',
        desc: '解锁全部 99 关',
        icon: '💍',
        progress: isAllLevelsCleared ? 1 : 0,
        target: 1,
      ),
      AchievementItem(
        title: 'Boss 猎人',
        desc: '打倒 3 次世界 Boss',
        icon: '🐉',
        progress: bossClears.clamp(0, 3),
        target: 3,
      ),
      AchievementItem(
        title: '糖果富翁',
        desc: '累计收集 200 颗马卡龙',
        icon: '💰',
        progress: totalCoins.clamp(0, 200),
        target: 200,
      ),
      AchievementItem(
        title: '衣帽间达人',
        desc: '拥有至少 3 件外观',
        icon: '✨',
        progress: ownedCosmeticIds.length.clamp(0, 3),
        target: 3,
      ),
    ];
  }

  bool _hasTripleStar() {
    final map = _decodeMap(_prefs?.getString(_keyStars) ?? '');
    return map.values.any((v) => v >= 3);
  }

  static int toGlobal(int world, int level) =>
      world * GameConstants.levelsPerWorld + level;

  static (int world, int level) fromGlobal(int global) {
    final w = global ~/ GameConstants.levelsPerWorld;
    final l = global % GameConstants.levelsPerWorld;
    return (w, l);
  }

  Map<int, int> _decodeMap(String raw) {
    if (raw.isEmpty) {
      return {};
    }
    final map = <int, int>{};
    for (final part in raw.split(';')) {
      if (part.isEmpty) {
        continue;
      }
      final kv = part.split(':');
      if (kv.length != 2) {
        continue;
      }
      final k = int.tryParse(kv[0]);
      final v = int.tryParse(kv[1]);
      if (k == null || v == null) {
        continue;
      }
      map[k] = v;
    }
    return map;
  }

  String _encodeMap(Map<int, int> map) =>
      map.entries.map((e) => '${e.key}:${e.value}').join(';');

  Set<String> _decodeSet(String raw) {
    if (raw.isEmpty) {
      return {};
    }
    return raw.split(';').where((e) => e.isNotEmpty).toSet();
  }

  String _encodeSet(Set<String> set) => set.join(';');
}

/// 成就条目
class AchievementItem {
  const AchievementItem({
    required this.title,
    required this.desc,
    required this.progress,
    required this.target,
    this.icon = '🎀',
  });

  final String title;
  final String desc;
  final String icon;
  final int progress;
  final int target;

  bool get unlocked => progress >= target;

  double get ratio => target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0);
}
