import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/data/audio_service.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/data/shop_catalog.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 外观商店页
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  @override
  Widget build(BuildContext context) {
    final wallet = SaveService.instance.walletCoins;
    final owned = SaveService.instance.ownedCosmeticIds;
    final equipped = SaveService.instance.equippedCosmeticId;

    return Scaffold(
      backgroundColor: MacaronColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      CupertinoIcons.back,
                      color: MacaronColors.cocoa,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      '糖果商店',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: MacaronColors.cocoa,
                      ),
                    ),
                  ),
                  Text(
                    '🍬 $wallet',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: MacaronColors.rose,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '用关卡收集的糖果兑换外观，穿上后立刻生效',
                style: TextStyle(color: MacaronColors.cocoa, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: ShopCatalog.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = ShopCatalog.items[i];
                  final has = owned.contains(item.id);
                  final on = equipped == item.id;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: on ? item.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: item.accent.withValues(alpha: 0.35),
                          child: Text(
                            item.name.substring(0, 1),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: MacaronColors.cocoa,
                                ),
                              ),
                              Text(
                                item.desc,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MacaronColors.cocoa.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                              Text(
                                item.price <= 0 ? '免费' : '🍬 ${item.price}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: MacaronColors.rose,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          color: on
                              ? MacaronColors.mint
                              : (has ? MacaronColors.sky : MacaronColors.rose),
                          borderRadius: BorderRadius.circular(14),
                          onPressed: () async {
                            await AudioService.instance.click();
                            if (on) {
                              return;
                            }
                            if (!has) {
                              final ok = await SaveService.instance
                                  .purchaseCosmetic(item.id);
                              if (!ok && context.mounted) {
                                await showCupertinoDialog<void>(
                                  context: context,
                                  builder: (ctx) => CupertinoAlertDialog(
                                    title: const Text('糖果不够'),
                                    content: const Text('再去闯关攒一点吧'),
                                    actions: [
                                      CupertinoDialogAction(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('好'),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }
                            }
                            await SaveService.instance.equipCosmetic(item.id);
                            if (mounted) {
                              setState(() {});
                            }
                          },
                          child: Text(
                            on ? '穿戴中' : (has ? '穿上' : '兑换'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
