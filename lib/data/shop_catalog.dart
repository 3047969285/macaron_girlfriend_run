import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 外观商品（用钱包糖果兑换）
class CosmeticItem {
  const CosmeticItem({
    required this.id,
    required this.name,
    required this.desc,
    required this.price,
    required this.accent,
  });

  final String id;
  final String name;
  final String desc;
  final int price;
  final Color accent;
}

/// 商店目录
class ShopCatalog {
  ShopCatalog._();

  static const String defaultId = 'classic';

  static const List<CosmeticItem> items = [
    CosmeticItem(
      id: defaultId,
      name: '经典甜妹',
      desc: '默认外观，免费常驻',
      price: 0,
      accent: MacaronColors.blush,
    ),
    CosmeticItem(
      id: 'ribbon',
      name: '草莓蝴蝶结',
      desc: '头顶系个粉红结',
      price: 40,
      accent: MacaronColors.rose,
    ),
    CosmeticItem(
      id: 'mint_trail',
      name: '薄荷拖尾',
      desc: '跑步时带薄荷绿光点',
      price: 80,
      accent: MacaronColors.mint,
    ),
    CosmeticItem(
      id: 'crown',
      name: '焦糖小皇冠',
      desc: '三星收藏家气质',
      price: 120,
      accent: MacaronColors.lemon,
    ),
    CosmeticItem(
      id: 'lilac_glow',
      name: '香芋光环',
      desc: '身周淡淡紫晕',
      price: 160,
      accent: MacaronColors.lilac,
    ),
    CosmeticItem(
      id: 'sparkle_shoes',
      name: '柠檬闪鞋',
      desc: '跑跳时洒下金色碎光',
      price: 200,
      accent: MacaronColors.lemon,
    ),
    CosmeticItem(
      id: 'strawberry_cape',
      name: '草莓披风',
      desc: '移动时飘落粉红糖屑',
      price: 240,
      accent: MacaronColors.rose,
    ),
  ];

  static CosmeticItem of(String id) {
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return items.first;
  }
}
