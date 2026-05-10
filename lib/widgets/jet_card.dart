import 'package:flutter/material.dart';
import '../models/jet_model.dart';

const _cGreen = Color(0xFF3B6D11);
const _cGreenLight = Color(0xFF97C459);
const _cGreenPale = Color(0xFFC0DD97);
const _cGreenMid = Color(0xFF639922);
const _cGreenDark = Color(0xFF173404);
const _cAmber = Color(0xFFEF9F27);
const _cAmberBg = Color(0xFF412402);
const _cBorderDefault = Color(0xFF1a3a1a);
const _cBorderOwned = Color(0xFF3B6D11);
const _cDivider = Color(0xFF1a2a1a);
const _cLockBg = Color(0xFF1a1a1a);
const _cLockLabel = Color(0xFF557733);
const _cUnlockText = Color(0xFF854F0B);
const _cLockedBorder = Color(0xFF2a2a2a);
const _cLockedText = Color(0xFF444444);

class JetCard extends StatelessWidget {
  final JetModel jet;
  final VoidCallback? onEquip;
  final VoidCallback? onBuy;

  const JetCard({
    super.key,
    required this.jet,
    this.onEquip,
    this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnedOrEquipped =
        jet.status == JetStatus.equipped || jet.status == JetStatus.owned;
    final isLocked = jet.status == JetStatus.locked;

    return Opacity(
      opacity: isLocked ? 0.48 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0d1f0d).withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOwnedOrEquipped ? _cBorderOwned : _cBorderDefault,
            width: 0.5,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  Center(child: _buildJetImage(context)),
                  const SizedBox(height: 4),
                  Text(
                    jet.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _cGreenPale,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    jet.tier,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 8, color: _cGreenMid),
                  ),
                  if (isLocked && jet.unlockCondition != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      jet.unlockCondition!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 8, color: _cUnlockText),
                    ),
                  ],
                  if (!isLocked) ...[
                    const SizedBox(height: 4),
                    _buildStatBar('Speed', jet.speed),
                    const SizedBox(height: 2),
                    _buildStatBar('Attack', jet.attack),
                    const SizedBox(height: 2),
                    _buildStatBar('Armor', jet.armor),
                  ],
                  const Spacer(),
                  _buildCtaButton(),
                ],
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: _buildBadge(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJetImage(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW - 28) / 2;
    final imgW = cardW * 0.42;
    final imgH = imgW * (62 / 52);

    return SizedBox(
      width: imgW,
      height: imgH,
      child: Container(
        decoration: BoxDecoration(
          color: jet.accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Image.asset(
          jet.assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              color: jet.accentColor,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBar(String label, int value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 7, color: _cLockLabel)),
                Text('$value',
                    style:
                        const TextStyle(fontSize: 7, color: _cLockLabel)),
              ],
            ),
            const SizedBox(height: 1),
            Container(
              width: totalW,
              height: 3,
              decoration: BoxDecoration(
                color: _cDivider,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: (value / 100).clamp(0.0, 1.0) * totalW,
                  height: 3,
                  decoration: BoxDecoration(
                    color: jet.accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBadge() {
    final String text;
    final Color bg;
    final Color textColor;

    switch (jet.status) {
      case JetStatus.equipped:
        text = 'Equipped';
        bg = _cGreenDark;
        textColor = _cGreenLight;
      case JetStatus.owned:
        text = 'Owned';
        bg = _cGreenDark;
        textColor = _cGreenLight;
      case JetStatus.purchasable:
        text = '💎 ${jet.price}';
        bg = _cAmberBg;
        textColor = _cAmber;
      case JetStatus.locked:
        text = 'Locked';
        bg = _cLockBg;
        textColor = _cLockLabel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 7, color: textColor),
      ),
    );
  }

  Widget _buildCtaButton() {
    final String label;
    final Color borderColor;
    final Color textColor;
    final VoidCallback? onTap;

    switch (jet.status) {
      case JetStatus.equipped:
        label = 'Equipped';
        borderColor = const Color(0xFF1a3a0a);
        textColor = _cGreen;
        onTap = null;
      case JetStatus.owned:
        label = 'Equip';
        borderColor = _cGreen;
        textColor = _cGreenLight;
        onTap = onEquip;
      case JetStatus.purchasable:
        label = 'Buy';
        borderColor = _cAmber;
        textColor = _cAmber;
        onTap = onBuy;
      case JetStatus.locked:
        label = 'Locked';
        borderColor = _cLockedBorder;
        textColor = _cLockedText;
        onTap = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 8, color: textColor),
        ),
      ),
    );
  }
}
