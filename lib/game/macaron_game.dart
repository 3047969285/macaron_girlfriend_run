import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/data/audio_service.dart';
import 'package:macaron_girlfriend_run/data/enemy_kind.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/effects/fx_layer.dart';
import 'package:macaron_girlfriend_run/game/effects/parallax_layer.dart';
import 'package:macaron_girlfriend_run/game/entities/entities.dart';
import 'package:macaron_girlfriend_run/game/player/girlfriend_player.dart';
import 'package:macaron_girlfriend_run/game/render/terrain_renderer.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 关卡结果
class LevelResult {
  const LevelResult({
    required this.cleared,
    required this.score,
    required this.coins,
    required this.stars,
    required this.kills,
    required this.timeLeft,
    this.bossCleared = false,
  });

  final bool cleared;
  final int score;
  final int coins;
  final int stars;
  final int kills;
  final int timeLeft;
  final bool bossCleared;
}

/// 马卡龙平台跳跃主游戏
class MacaronGame extends FlameGame {
  MacaronGame({
    required this.worldIndex,
    required this.levelIndex,
    required this.role,
    this.onHudChanged,
    this.onWin,
    this.onLoseLife,
    this.onGameOver,
  }) : palette = WorldCatalog.paletteOf(worldIndex);

  final int worldIndex;
  final int levelIndex;
  final PlayerRole role;
  final VoidCallback? onHudChanged;
  final void Function(LevelResult result)? onWin;
  final VoidCallback? onLoseLife;
  final VoidCallback? onGameOver;

  late LevelData level;
  final WorldPalette palette;
  late GirlfriendPlayer player;
  late Vector2 spawnPoint;

  final List<TerrainTile> terrain = [];
  final List<MacaronCoin> coins = [];
  final List<SoftEnemy> enemies = [];
  final List<QuestionBlock> blocks = [];
  final List<PowerMacaron> powers = [];
  final List<LifeHeart> hearts = [];
  final List<SpringPad> springs = [];
  final List<CheckpointPad> checkpoints = [];
  GoalFlag? goal;
  MacaronBoss? boss;
  late FxLayer fx;
  ParallaxLayer? parallax;

  bool leftPressed = false;
  bool rightPressed = false;
  bool runPressed = false;
  bool duckPressed = false;
  bool jumpHeld = false;
  bool _jumpArmed = true;
  bool jumpPressedEdge = false;

  bool userPaused = false;
  bool levelReady = false;
  bool _finished = false;
  int collected = 0;
  int totalCoins = 0;
  int score = 0;
  int lives = GameConstants.startingLives;
  int kills = 0;
  double timeLeft = GameConstants.levelTimeLimit.toDouble();
  double powerTimer = 0;
  double _hudAcc = 0;
  double _shakeTimer = 0;
  double _shakeMag = 0;
  double _springLock = 0;
  double _trailAcc = 0;
  double _lookAhead = 0;
  List<Rect> _cachedSolids = const [];
  List<List<Rect>> _solidsByCol = const [];

  bool get poweredUpVisible => levelReady && player.poweredUp;

  double mathMax(double a, double b) => a > b ? a : b;

  @override
  Color backgroundColor() => palette.skyBottom;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    level = LevelCatalog.load(worldIndex, levelIndex);
    _buildLevel();
    timeLeft = GameConstants.timeLimitFor(
      level.difficulty,
      mapWidth: level.width,
    );
    camera.viewfinder.anchor = Anchor.center;
    levelReady = true;
    _notifyHud();
    // 尺寸就绪后再对准镜头
    if (size.x > 0 && size.y > 0) {
      _snapCamera();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _snapCamera();
    }
  }

  void _notifyHud() => onHudChanged?.call();

  void _buildLevel() {
    terrain.clear();
    coins.clear();
    enemies.clear();
    blocks.clear();
    powers.clear();
    hearts.clear();
    springs.clear();
    checkpoints.clear();
    goal = null;
    boss = null;
    world.removeAll(world.children.toList());

    final tile = GameConstants.tileSize;
    spawnPoint = Vector2(tile * 2, tile * 8);
    final groundY = (level.height - 1) * tile;

    parallax = ParallaxLayer(
      mapWidth: level.width * tile,
      farColor: palette.parallaxFar,
      midColor: palette.parallaxMid,
    );
    world.add(parallax!);
    world.add(WorldBackdrop(palette: palette, mapWidth: level.width * tile));
    world.add(
      AmbientSparkles(
        mapWidth: level.width * tile,
        tint: palette.accent,
      ),
    );
    fx = FxLayer();
    world.add(fx);

    for (var y = 0; y < level.height; y++) {
      for (var x = 0; x < level.width; x++) {
        final t = level.tileAt(x, y);
        final px = x * tile;
        final py = y * tile;
        switch (t) {
          case '#':
            terrain.add(TerrainTile(rect: Rect.fromLTWH(px, py, tile, tile), isGround: true));
            break;
          case '=':
            terrain.add(TerrainTile(rect: Rect.fromLTWH(px, py, tile, tile), isGround: false));
            break;
          case 'P':
            spawnPoint = Vector2(px + tile / 2, py + tile);
            break;
          case 'F':
            goal = GoalFlag(position: Vector2(px + tile / 2, py + tile));
            break;
          case 'C':
            if (coins.length < 96) {
              coins.add(MacaronCoin(position: Vector2(px + tile / 2, py + tile / 2)));
            }
            break;
          case 'E':
            _addEnemy(px, py, tile, EnemyKind.walker);
            break;
          case 'G':
            _addEnemy(px, py, tile, EnemyKind.hopper);
            break;
          case 'R':
            _addEnemy(px, py, tile, EnemyKind.bruiser);
            break;
          case 'B':
            boss = MacaronBoss(
              position: Vector2(px + tile / 2, py + tile),
              leftBound: px - tile * 3,
              rightBound: px + tile * 4,
              maxHp: 3 + (worldIndex ~/ 3),
            );
            break;
          case 'K':
            checkpoints.add(CheckpointPad(position: Vector2(px + tile / 2, py + tile)));
            break;
          case '?':
            blocks.add(QuestionBlock(position: Vector2(px, py)));
            terrain.add(TerrainTile(rect: Rect.fromLTWH(px, py, tile, tile), isGround: false));
            break;
          case 'M':
            powers.add(PowerMacaron(position: Vector2(px + tile / 2, py + tile / 2)));
            break;
          case 'H':
            hearts.add(LifeHeart(position: Vector2(px + tile / 2, py + tile / 2)));
            break;
          case 'S':
            springs.add(SpringPad(position: Vector2(px, py + tile - 20)));
            break;
        }
      }
    }

    totalCoins = coins.length;
    _cachedSolids = terrain.map((e) => e.rect).toList(growable: false);
    _rebuildSolidBuckets();
    world.add(
      TerrainRenderer(
        solids: terrain,
        palette: palette,
        mapWidth: level.width * tile,
        groundY: groundY,
      ),
    );
    for (final b in blocks) {
      world.add(b);
    }
    for (final c in coins) {
      world.add(c);
    }
    for (final e in enemies) {
      world.add(e);
    }
    for (final p in powers) {
      world.add(p);
    }
    for (final h in hearts) {
      world.add(h);
    }
    for (final s in springs) {
      world.add(s);
    }
    for (final k in checkpoints) {
      world.add(k);
    }
    if (boss != null) {
      world.add(boss!);
    }
    if (goal != null) {
      world.add(goal!);
    }
    final cosmetic = SaveService.instance.equippedCosmeticId;
    player = GirlfriendPlayer(role: role, cosmeticId: cosmetic)
      ..position = spawnPoint.clone();
    world.add(player);
    _notifyHud();
  }

  void _addEnemy(double px, double py, double tile, EnemyKind kind) {
    if (enemies.length >= GameConstants.maxActiveEnemies) {
      return;
    }
    enemies.add(
      SoftEnemy(
        position: Vector2(px + tile / 2, py + tile),
        leftBound: px - tile * 1.5,
        rightBound: px + tile * 2.5,
        speed: GameConstants.enemySpeedFor(level.difficulty) *
            (kind == EnemyKind.hopper ? 1.15 : 1.0),
        kind: kind,
      ),
    );
  }

  void _rebuildSolidBuckets() {
    final cols = level.width;
    _solidsByCol = List.generate(cols, (_) => <Rect>[]);
    final tile = GameConstants.tileSize;
    for (final r in _cachedSolids) {
      final x0 = (r.left / tile).floor().clamp(0, cols - 1);
      final x1 = ((r.right - 0.01) / tile).floor().clamp(0, cols - 1);
      for (var x = x0; x <= x1; x++) {
        _solidsByCol[x].add(r);
      }
    }
  }

  /// 仅取玩家附近列的固体，降低长关扫描成本
  List<Rect> _nearbySolids(Rect hitbox) {
    if (_solidsByCol.isEmpty) {
      return _cachedSolids;
    }
    final tile = GameConstants.tileSize;
    final cols = _solidsByCol.length;
    final x0 = ((hitbox.left - tile) / tile).floor().clamp(0, cols - 1);
    final x1 = ((hitbox.right + tile) / tile).floor().clamp(0, cols - 1);
    final seen = <Rect>{};
    final out = <Rect>[];
    for (var x = x0; x <= x1; x++) {
      for (final r in _solidsByCol[x]) {
        if (seen.add(r)) {
          out.add(r);
        }
      }
    }
    return out;
  }

  void tapJump() {
    setJumpHeld(true);
  }

  /// 跳跃按键按下松开必须成对，松开后才能再跳，防止连跳多动症
  void setJumpHeld(bool held) {
    if (userPaused || _finished) {
      jumpHeld = false;
      return;
    }
    if (held) {
      if (_jumpArmed && !jumpHeld) {
        jumpPressedEdge = true;
        _jumpArmed = false;
      }
      jumpHeld = true;
    } else {
      jumpHeld = false;
      _jumpArmed = true;
    }
  }

  void setDuckPressed(bool value) {
    duckPressed = value;
    if (value) {
      // 蹲下时清掉跳跃缓冲，避免刚蹲就被缓冲顶飞
      if (levelReady) {
        player.jumpBufferTimer = 0;
      }
    }
  }

  void setPaused(bool value) {
    // 仅用逻辑暂停，不调 pauseEngine，否则 GameWidget 会整屏黑掉
    userPaused = value;
  }

  void _snapCamera() {
    if (!levelReady || size.x <= 0 || size.y <= 0) {
      return;
    }
    final mapW = level.width * GameConstants.tileSize;
    final mapH = level.height * GameConstants.tileSize;
    final look = player.facingRight
        ? GameConstants.cameraLookAhead * 0.55
        : -GameConstants.cameraLookAhead * 0.55;
    var cx = player.position.x + look;
    var cy = player.position.y - 80;
    final minX = size.x / 2;
    final maxX = mathMax(minX, mapW - size.x / 2);
    final minY = size.y / 2;
    final maxY = mathMax(minY, mapH - size.y / 2);
    camera.viewfinder.position =
        Vector2(cx.clamp(minX, maxX), cy.clamp(minY, maxY));
  }

  @override
  void update(double dt) {
    super.update(dt);
    // onLoad 完成前 player 尚未创建，必须跳过逻辑避免 LateInitializationError
    if (!levelReady || userPaused || _finished) {
      return;
    }

    if (enemies.isNotEmpty && size.x > 0) {
      final camX = camera.viewfinder.position.x;
      final margin = size.x * 0.85 + 220;
      for (final e in enemies) {
        e.simActive = (e.position.x - camX).abs() < margin;
      }
    }

    if (player.dead) {
      player.velocity.y += GameConstants.gravity * dt;
      player.position += player.velocity * dt;
      _updateCamera(dt);
      if (player.position.y > level.height * GameConstants.tileSize + 220) {
        _afterDeath();
      }
      return;
    }

    final clampedDt = dt.clamp(0.0, 1 / 30);
    if (_springLock > 0) {
      _springLock = (_springLock - clampedDt).clamp(0.0, 2.0);
    }
    timeLeft = (timeLeft - clampedDt).clamp(
      0.0,
      GameConstants.timeLimitFor(
        level.difficulty,
        mapWidth: level.width,
      ),
    );
    if (timeLeft <= 0) {
      _hurtOrKill(forceKill: true);
      return;
    }
    if (powerTimer > 0) {
      powerTimer -= clampedDt;
      if (powerTimer <= 0) {
        player.poweredUp = false;
      }
    }

    _simulatePlayer(clampedDt);
    _emitCosmeticTrail(clampedDt);
    _resolveCollectibles();
    _resolveBlocks();
    _resolvePowers();
    _resolveHearts();
    _resolveSprings();
    _resolveCheckpoints();
    _resolveEnemies();
    _resolveBoss();
    _resolveGoal();
    _updateCamera(clampedDt);
    // HUD 约 10 次/秒，配合 ValueListenable 只刷条而不是整页
    _hudAcc += clampedDt;
    if (_hudAcc >= 0.1) {
      _hudAcc = 0;
      _notifyHud();
    }
  }

  void _simulatePlayer(double dt) {
    final jumpedEdge = jumpPressedEdge;
    jumpPressedEdge = false;
    player.applyInput(
      left: leftPressed,
      right: rightPressed,
      run: runPressed,
      jumpPressed: jumpedEdge,
    );
    // 先处理下蹲，再决定能不能跳
    player.applyDuck(duckPressed && !player.dead);

    final ducking = player.ducking;
    final speed = ducking
        ? GameConstants.moveSpeed * 0.45
        : (player.wantsRun ? GameConstants.runSpeed : GameConstants.moveSpeed);
    if (player.wantsLeft && !player.wantsRight) {
      player.velocity.x = -speed;
      player.facingRight = false;
    } else if (player.wantsRight && !player.wantsLeft) {
      player.velocity.x = speed;
      player.facingRight = true;
    } else {
      player.velocity.x = 0;
    }

    if (player.onGround) {
      player.coyoteTimer = GameConstants.coyoteTime;
    } else {
      player.coyoteTimer -= dt;
    }
    player.jumpBufferTimer -= dt;

    // 蹲着按跳：允许起跳去顶砖；没按跳时绝不自动跳
    final wantJump = jumpedEdge || player.jumpBufferTimer > 0;
    final canJump = player.coyoteTimer > 0 && (!ducking || jumpedEdge);
    if (wantJump && canJump) {
      player.velocity.y = player.poweredUp
          ? GameConstants.superJumpVelocity
          : GameConstants.jumpVelocity;
      player.onGround = false;
      player.coyoteTimer = 0;
      player.jumpBufferTimer = 0;
      player.applyDuck(false);
      AudioService.instance.jump();
      fx.jumpDust(
        player.position.clone(),
        tint: player.poweredUp ? MacaronColors.lilac : null,
      );
    } else if (ducking) {
      player.jumpBufferTimer = 0;
    }

    player.velocity.y += GameConstants.gravity * dt;
    // 松开跳跃：截断上升，短跳更可控
    if (!jumpHeld &&
        player.velocity.y < GameConstants.jumpCutVelocity) {
      player.velocity.y = GameConstants.jumpCutVelocity;
    }
    if (player.velocity.y > 1400) {
      player.velocity.y = 1400;
    }

    final wasRising = player.velocity.y < 0;
    _moveAxis(dt, horizontal: true);
    _moveAxis(dt, horizontal: false);
    if (wasRising || player.velocity.y <= 0) {
      _tryHeadBumpBlocks();
    }

    if (player.position.y >
        level.height * GameConstants.tileSize + GameConstants.tileSize) {
      _hurtOrKill(forceKill: true);
    }
  }

  void _moveAxis(double dt, {required bool horizontal}) {
    final delta = horizontal
        ? Vector2(player.velocity.x * dt, 0)
        : Vector2(0, player.velocity.y * dt);
    player.position += delta;
    final hitbox = _playerHitbox();
    final solids = _nearbySolids(hitbox);
    player.onGround = false;
    for (final solid in solids) {
      if (!hitbox.overlaps(solid)) {
        continue;
      }
      if (horizontal) {
        if (delta.x > 0) {
          player.position.x = solid.left - player.size.x * 0.5;
        } else if (delta.x < 0) {
          player.position.x = solid.right + player.size.x * 0.5;
        }
        player.velocity.x = 0;
      } else {
        if (delta.y > 0) {
          player.position.y = solid.top;
          player.velocity.y = 0;
          player.onGround = true;
        } else if (delta.y < 0) {
          player.position.y = solid.bottom + player.hitHeight;
          player.velocity.y = 0;
          _bumpBlocksAbove(solid);
        }
      }
    }
  }

  void _bumpBlocksAbove(Rect solid) {
    final probe = solid.inflate(6);
    for (final b in blocks) {
      if (b.used) {
        continue;
      }
      final r = Rect.fromLTWH(b.position.x, b.position.y, b.size.x, b.size.y);
      if (r.overlaps(probe)) {
        _activateBlock(b);
        break;
      }
    }
  }

  /// 头顶扫问号砖：用宽松重叠，避免撞墙后判定失效
  void _tryHeadBumpBlocks() {
    final box = _playerHitbox();
    final headZone = Rect.fromLTRB(
      box.left + 2,
      box.top - 16,
      box.right - 2,
      box.top + 14,
    );
    for (final b in blocks) {
      if (b.used) {
        continue;
      }
      final r = Rect.fromLTWH(b.position.x, b.position.y, b.size.x, b.size.y);
      final aboveFeet = r.bottom <= player.position.y - 4;
      if (aboveFeet && (headZone.overlaps(r) || box.overlaps(r))) {
        _activateBlock(b);
        if (player.velocity.y < 0) {
          player.velocity.y = 80;
        }
        final minFeet = r.bottom + player.hitHeight;
        if (player.position.y < minFeet) {
          player.position.y = minFeet;
        }
        break;
      }
    }
  }

  void _activateBlock(QuestionBlock b) {
    if (b.used) {
      return;
    }
    b.hit();
    _spawnFromBlock(b);
    fx.blockBump(Vector2(b.position.x + 24, b.position.y));
    AudioService.instance.coin();
  }

  void _spawnFromBlock(QuestionBlock b) {
    final roll = (b.position.x ~/ 48) % 3;
    final pos = Vector2(b.position.x + 24, b.position.y - 20);
    if (roll == 0) {
      final c = MacaronCoin(position: pos);
      coins.add(c);
      totalCoins++;
      world.add(c);
    } else if (roll == 1) {
      final p = PowerMacaron(position: pos);
      powers.add(p);
      world.add(p);
    } else {
      score += GameConstants.coinScore;
      collected++;
      world.add(ScoreCandyBurst(position: pos.clone()));
      fx.coinSparkle(pos.clone());
    }
  }

  Rect _playerHitbox() {
    final h = player.hitHeight;
    return Rect.fromCenter(
      center: Offset(player.position.x, player.position.y - h / 2),
      width: player.size.x * 0.65,
      height: h * 0.9,
    );
  }

  void _resolveCollectibles() {
    final box = _playerHitbox();
    for (final coin in coins) {
      if (coin.collected) {
        continue;
      }
      final c = Rect.fromCenter(
        center: Offset(coin.position.x, coin.position.y),
        width: coin.size.x,
        height: coin.size.y,
      );
      if (box.overlaps(c)) {
        coin.collected = true;
        coin.removeFromParent();
        collected++;
        player.coins++;
        score += GameConstants.coinScore;
        AudioService.instance.coin();
        fx.coinSparkle(coin.position.clone());
      }
    }
  }

  void _resolveBlocks() {
    // 上升或刚顶到天花板时都再扫一次，避免漏判
    if (player.velocity.y > 120) {
      return;
    }
    _tryHeadBumpBlocks();
  }

  void _resolvePowers() {
    final box = _playerHitbox();
    for (final p in powers) {
      if (p.collected) {
        continue;
      }
      final r = Rect.fromCenter(
        center: Offset(p.position.x, p.position.y),
        width: p.size.x,
        height: p.size.y,
      );
      if (box.overlaps(r)) {
        p.collected = true;
        p.removeFromParent();
        player.grantPower();
        powerTimer = GameConstants.powerUpDuration;
        score += 300;
        AudioService.instance.powerUp();
        fx.powerUp(p.position.clone());
      }
    }
  }

  void _resolveHearts() {
    final box = _playerHitbox();
    for (final h in hearts) {
      if (h.collected) {
        continue;
      }
      final r = Rect.fromCenter(
        center: Offset(h.position.x, h.position.y),
        width: h.size.x,
        height: h.size.y,
      );
      if (box.overlaps(r)) {
        h.collected = true;
        h.removeFromParent();
        if (lives < GameConstants.maxLives) {
          lives++;
        }
        score += 500;
        AudioService.instance.powerUp();
        fx.powerUp(h.position.clone());
      }
    }
  }

  void _emitCosmeticTrail(double dt) {
    final id = player.cosmeticId;
    if (id != 'mint_trail' && id != 'sparkle_shoes' && id != 'strawberry_cape') {
      return;
    }
    if (player.velocity.x.abs() < 40 && player.onGround) {
      return;
    }
    _trailAcc += dt;
    if (_trailAcc < 0.05) {
      return;
    }
    _trailAcc = 0;
    final color = id == 'mint_trail'
        ? MacaronColors.mint
        : (id == 'sparkle_shoes' ? MacaronColors.lemon : MacaronColors.rose);
    fx.softTrail(
      player.position + Vector2(player.facingRight ? -10 : 10, -18),
      color,
    );
  }

  void _resolveSprings() {
    if (_springLock > 0 || player.velocity.y <= 40) {
      return;
    }
    final box = _playerHitbox();
    for (final s in springs) {
      final r = Rect.fromLTWH(s.position.x, s.position.y, s.size.x, s.size.y);
      if (box.overlaps(r)) {
        s.bounce();
        player.velocity.y = GameConstants.superJumpVelocity * 1.05;
        player.onGround = false;
        player.jumpBufferTimer = 0;
        _springLock = 0.22;
        AudioService.instance.jump();
        fx.springPop(Vector2(s.position.x + 24, s.position.y));
        break;
      }
    }
  }

  void _resolveCheckpoints() {
    final box = _playerHitbox();
    for (final k in checkpoints) {
      if (k.activated) {
        continue;
      }
      final r = Rect.fromCenter(
        center: Offset(k.position.x, k.position.y - k.size.y / 2),
        width: k.size.x,
        height: k.size.y,
      );
      if (box.overlaps(r)) {
        k.activate();
        spawnPoint = k.position.clone();
        score += 50;
        AudioService.instance.powerUp();
        fx.powerUp(k.position.clone());
      }
    }
  }

  void _resolveBoss() {
    final b = boss;
    if (b == null || b.dead) {
      return;
    }
    final box = _playerHitbox();
    final e = Rect.fromCenter(
      center: Offset(b.position.x, b.position.y - b.size.y / 2),
      width: b.size.x * 0.8,
      height: b.size.y * 0.85,
    );
    if (!box.overlaps(e)) {
      return;
    }
    if (player.velocity.y > 0 &&
        player.position.y - player.size.y * 0.2 <
            b.position.y - b.size.y * 0.35) {
      final becameEnraged = b.stompHit();
      player.velocity.y = GameConstants.jumpVelocity * 0.6;
      score += GameConstants.enemyScore;
      _triggerShake(b.enraged ? 1.8 : 1.4);
      AudioService.instance.stomp();
      fx.stompKill(b.position.clone());
      if (becameEnraged) {
        fx.powerUp(b.position.clone());
        score += 200;
      }
      if (b.dead) {
        kills++;
        score += 1200;
        b.removeFromParent();
        for (var i = 0; i < 6; i++) {
          final c = MacaronCoin(
            position: b.position + Vector2((i - 2.5) * 16.0, -40),
          );
          coins.add(c);
          totalCoins++;
          world.add(c);
        }
        // 狂暴阶段掉落一颗超级跳
        final p = PowerMacaron(position: b.position + Vector2(0, -60));
        powers.add(p);
        world.add(p);
      }
    } else if (b.isSlamming || !player.isInvincible) {
      _hurtOrKill();
    }
  }

  void _resolveEnemies() {
    final box = _playerHitbox();
    for (final enemy in List<SoftEnemy>.from(enemies)) {
      if (enemy.dead) {
        continue;
      }
      final e = Rect.fromCenter(
        center: Offset(enemy.position.x, enemy.position.y - enemy.size.y / 2),
        width: enemy.size.x * 0.8,
        height: enemy.size.y * 0.8,
      );
      if (!box.overlaps(e)) {
        continue;
      }
      if (player.velocity.y > 0 &&
          player.position.y - player.size.y * 0.2 <
              enemy.position.y - enemy.size.y * 0.4) {
        final killed = enemy.takeStomp();
        player.velocity.y = GameConstants.jumpVelocity * 0.55;
        _triggerShake(1);
        AudioService.instance.stomp();
        fx.stompKill(enemy.position.clone());
        if (killed) {
          enemy.removeFromParent();
          enemies.remove(enemy);
          kills++;
          score += GameConstants.enemyScore *
              (enemy.kind == EnemyKind.bruiser ? 2 : 1);
        } else {
          score += 50;
        }
      } else {
        _hurtOrKill();
      }
    }
  }

  void _hurtOrKill({bool forceKill = false}) {
    if (!forceKill && player.isInvincible) {
      return;
    }
    if (!forceKill && player.poweredUp) {
      player.poweredUp = false;
      powerTimer = 0;
      player.hurtFlash();
      AudioService.instance.hurt();
      return;
    }
    AudioService.instance.hurt();
    player.kill();
  }

  void _afterDeath() {
    lives--;
    _notifyHud();
    if (lives <= 0) {
      _finished = true;
      onGameOver?.call();
      return;
    }
    onLoseLife?.call();
    player.reviveAt(spawnPoint.clone());
    // 保留剩余限时；若因超时死亡则给一小段续命时间
    if (timeLeft < 28) {
      timeLeft = 28;
    }
    _snapCamera();
  }

  void _resolveGoal() {
    if (goal == null || _finished) {
      return;
    }
    if (boss != null && !boss!.dead) {
      return;
    }
    final box = _playerHitbox();
    final g = Rect.fromCenter(
      center: Offset(goal!.position.x, goal!.position.y - goal!.size.y / 2),
      width: goal!.size.x,
      height: goal!.size.y,
    );
    if (box.overlaps(g)) {
      _finished = true;
      player.reachedGoal = true;
      fx.winConfetti(goal!.position.clone());
      final timeBonus =
          (timeLeft.floor() * GameConstants.timeBonusPerSecond);
      score += GameConstants.clearBonus + timeBonus;
      AudioService.instance.win();
      onWin?.call(
        LevelResult(
          cleared: true,
          score: score,
          coins: collected,
          stars: starRating(),
          kills: kills,
          timeLeft: timeLeft.floor(),
          bossCleared: boss != null,
        ),
      );
    }
  }

  void _triggerShake([double mag = 1]) {
    _shakeTimer = 0.18;
    _shakeMag = mag;
  }

  void _updateCamera(double dt) {
    if (size.x <= 0 || size.y <= 0) {
      return;
    }
    if (_shakeTimer > 0) {
      _shakeTimer = (_shakeTimer - dt).clamp(0.0, 1.0);
    }
    final mapW = level.width * GameConstants.tileSize;
    final mapH = level.height * GameConstants.tileSize;
    final wantLook = (player.facingRight ? 1.0 : -1.0) *
        GameConstants.cameraLookAhead *
        (player.wantsRun ? 1.0 : 0.55);
    _lookAhead += (wantLook - _lookAhead) * (6 * dt).clamp(0.0, 1.0);
    var cx = player.position.x + _lookAhead;
    var cy = player.position.y - 80;
    if (_shakeTimer > 0) {
      final s = _shakeMag * (_shakeTimer / 0.18);
      final amp = GameConstants.cameraShakeMax * s;
      cx += math.sin(_shakeTimer * 42) * amp;
      cy += math.cos(_shakeTimer * 38) * amp * 0.7;
    }
    final minX = size.x / 2;
    final maxX = mathMax(minX, mapW - size.x / 2);
    final minY = size.y / 2;
    final maxY = mathMax(minY, mapH - size.y / 2);
    cx = cx.clamp(minX, maxX);
    cy = cy.clamp(minY, maxY);
    final cur = camera.viewfinder.position;
    final follow = (10 * dt).clamp(0.0, 1.0);
    camera.viewfinder.position = Vector2(
      cur.x + (cx - cur.x) * follow,
      cur.y + (cy - cur.y) * follow,
    );
    parallax?.syncCamera(camera.viewfinder.position.x);
  }

  int starRating() {
    var stars = 1;
    if (totalCoins <= 0) {
      if (timeLeft >= 90) {
        return 3;
      }
      if (timeLeft >= 60) {
        return 2;
      }
      return 1;
    }
    if (collected >= (totalCoins * 0.58).ceil()) {
      stars = 2;
    }
    if (collected >= (totalCoins * 0.88).ceil() && timeLeft >= 45) {
      stars = 3;
    }
    return stars;
  }

  @override
  void render(Canvas canvas) {
    final rect = Offset.zero & size.toSize();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.skyTop, palette.skyBottom],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
    super.render(canvas);
  }
}
