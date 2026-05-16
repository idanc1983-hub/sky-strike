import 'package:flutter/material.dart';
import '../models/jet_model.dart';
import '../shared/widgets/asset_placeholder.dart';

const _cGreen = Color(0xFF3B6D11);
const _cGreenSolid = Color(0xFF4F8A1A);
const _cGreenDim = Color(0xFF2a4a10);
const _cBarTrack = Color(0xFF0d1a0d);
const _cBorderDefault = Color(0xFF1a3a1a);
const _cBorderOwned = Color(0xFF3B6D11);
const _cLockedBorder = Color(0xFF2a2a2a);
const _cLockedBg = Color(0xFF1a1a1a);
const _cLockedText = Color(0xFF666666);
const _cUnlockText = Color(0xFF854F0B);
const _cStatLabel = Color(0xFFC0DD97);
const _cStatValue = Color(0xFFEF9F27);
const _cAmberBar = Color(0xFFEF9F27);

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
      opacity: isLocked ? 0.55 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0a1606).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOwnedOrEquipped ? _cBorderOwned : _cBorderDefault,
            width: 0.6,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 130,
                child: Center(child: _buildJetImage()),
              ),
              if (isLocked && jet.unlockCondition != null) ...[
                const SizedBox(height: 6),
                Text(
                  jet.unlockCondition!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _cUnlockText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (!isLocked) ...[
                const SizedBox(height: 14),
                _buildStatRow('Speed', jet.speed),
                const SizedBox(height: 10),
                _buildStatRow('Attack', jet.attack),
                const SizedBox(height: 10),
                _buildStatRow('Armor', jet.armor),
              ],
              const SizedBox(height: 16),
              _buildCtaButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJetImage() {
    return Image.asset(
      jet.assetPath,
      height: 120,
      fit: BoxFit.contain,
      errorBuilder: AssetPlaceholder.image(
        color: jet.accentColor,
        label: jet.name,
        borderRadius: 8,
      ),
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: _cStatLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 12,
                color: _cStatValue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            final totalW = constraints.maxWidth;
            return Container(
              width: totalW,
              height: 8,
              decoration: BoxDecoration(
                color: _cBarTrack,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: (value / 100).clamp(0.0, 1.0) * totalW,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _cAmberBar,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Solid green button — shows "{price} 💎" with a gem icon for every
  // unlocked jet. Tap action varies by status: purchasable → buy popup,
  // owned → equip immediately, equipped → no-op. Locked jets get a
  // disabled dark variant labelled "Locked".
  Widget _buildCtaButton() {
    final bool isLocked = jet.status == JetStatus.locked;
    final bool isEquipped = jet.status == JetStatus.equipped;
    final Color bg;
    final VoidCallback? onTap;

    switch (jet.status) {
      case JetStatus.equipped:
        bg = _cGreenDim;
        onTap = null;
      case JetStatus.owned:
        bg = _cGreenSolid;
        onTap = onEquip;
      case JetStatus.purchasable:
        bg = _cGreenSolid;
        onTap = onBuy;
      case JetStatus.locked:
        bg = _cLockedBg;
        onTap = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: isLocked ? _cLockedBorder : _cGreen,
            width: 0.7,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: isLocked ? _buildLockedLabel() : _buildPriceLabel(isEquipped),
      ),
    );
  }

  Widget _buildLockedLabel() {
    return const Text(
      'Locked',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        color: _cLockedText,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPriceLabel(bool isEquipped) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${jet.price}',
          style: TextStyle(
            fontSize: 15,
            color: isEquipped ? const Color(0xFFA5C97A) : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 16,
          height: 16,
          child: Image.asset(
            'assets/ui/icon_gem.png',
            errorBuilder: AssetPlaceholder.image(
              color: const Color(0xFF7BB8FF),
              label: 'gem',
              borderRadius: 3,
            ),
          ),
        ),
      ],
    );
  }
}
