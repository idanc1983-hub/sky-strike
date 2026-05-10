import 'package:flutter/foundation.dart';

import '../models/bundle_content.dart';
import '../models/bundle_price.dart';
import '../models/shop_bundle.dart';

/// Outcome of validating one bundle.
class ValidationResult {
  final bool isValid;
  final List<String> errors;

  const ValidationResult(this.isValid, this.errors);

  /// Convenience factory for the success case.
  static const ValidationResult valid = ValidationResult(true, <String>[]);

  /// Convenience factory for the failure case.
  factory ValidationResult.invalid(List<String> errors) =>
      ValidationResult(false, List.unmodifiable(errors));
}

/// Sink for validator failures. Default implementation prints with a
/// `[BUNDLE_VALIDATION_FAIL]` tag; tests inject a recorder to assert the
/// hook fired without coupling to `print`.
typedef BundleValidationLogger = void Function(
  String bundleId,
  List<String> errors,
);

void _defaultValidationLogger(String bundleId, List<String> errors) {
  // Per build prompt this is the explicit analytics stub.
  // ignore: avoid_print
  print('[BUNDLE_VALIDATION_FAIL] $bundleId errors=${errors.join("; ")}');
}

/// Schema and sanity checker for [ShopBundle] records returned by the
/// repository. A bundle that fails any rule must be **silently dropped** —
/// the user never sees a half-broken record, but the failure is logged.
class BundleValidator {
  static final RegExp _idPattern = RegExp(r'^[a-z0-9_]+$');
  static final RegExp _experimentKeyPattern = RegExp(r'^[a-z0-9_]+$');
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  final BundleValidationLogger _log;

  BundleValidator({BundleValidationLogger? log})
      : _log = log ?? _defaultValidationLogger;

  /// Validates [bundle] and emits a [ValidationResult]. Failure cases also
  /// emit a log line via the configured logger.
  ValidationResult validate(ShopBundle bundle) {
    final errors = <String>[];

    // 1. Required fields
    if (bundle.id.isEmpty) errors.add('id missing');
    if (bundle.localizationKey.isEmpty) errors.add('localizationKey missing');
    if (bundle.theme.themeId.isEmpty) errors.add('theme.themeId missing');
    if (bundle.contents.isEmpty) errors.add('contents empty');
    if (bundle.analyticsTag.isEmpty) errors.add('analyticsTag missing');

    // 2. ID format & length
    if (bundle.id.isNotEmpty) {
      if (!_idPattern.hasMatch(bundle.id)) {
        errors.add('id format must match ^[a-z0-9_]+\$');
      }
      if (bundle.id.length < 3 || bundle.id.length > 64) {
        errors.add('id length must be 3..64');
      }
    }

    // 3. Time window
    if (bundle.startsAt == _epoch) errors.add('startsAt missing/invalid');
    if (bundle.endsAt == _epoch) errors.add('endsAt missing/invalid');
    if (bundle.startsAt != _epoch &&
        bundle.endsAt != _epoch &&
        !bundle.endsAt.isAfter(bundle.startsAt)) {
      errors.add('endsAt must be after startsAt');
    }

    // 4. Contents
    for (var i = 0; i < bundle.contents.length; i++) {
      final c = bundle.contents[i];
      if (c.hasUnknownType) {
        errors.add(
          'contents[$i].type "${c.rawType}" is not a known content discriminator',
        );
      }
      if (c.count <= 0) errors.add('contents[$i].count must be > 0');
      if (c.requiresItemId && (c.itemId == null || c.itemId!.isEmpty)) {
        errors.add(
          'contents[$i].itemId required for type ${c.type.jsonValue}',
        );
      }
      if (!c.requiresItemId &&
          c.itemId != null &&
          c.type != BundleContentType.xpBoost) {
        // xp_boost type is allowed to carry an itemId per design but isn't
        // required to. gems/coins must NOT carry one.
        if (c.type == BundleContentType.gems ||
            c.type == BundleContentType.coins) {
          errors.add(
            'contents[$i].itemId must be null for type ${c.type.jsonValue}',
          );
        }
      }
      if (c.iconAsset.isEmpty) {
        errors.add('contents[$i].iconAsset missing');
      }
    }

    // 5. Price sanity
    final p = bundle.price;
    if (p.type == BundlePriceType.gems) {
      if (p.gemCost == null || p.gemCost! <= 0) {
        errors.add('price.gemCost must be > 0 for gem-priced bundle');
      }
    } else {
      if (p.iapProductId == null || p.iapProductId!.isEmpty) {
        errors.add('price.iapProductId required for IAP bundle');
      }
      // The button can only render a real currency string when the
      // catalog has shipped a non-null usdEquivalent. Without it the
      // UI falls back to a generic "Buy" label which is confusing
      // when paired with a strikethrough comparison price.
      if (p.usdEquivalent == null || p.usdEquivalent! <= 0) {
        errors.add('price.usdEquivalent must be > 0 for IAP bundle');
      }
    }

    // 6. Compare price strictly greater than actual price.
    // 6a. compareGems requires a valid gemCost on a gems-priced bundle.
    if (p.compareGems != null) {
      if (p.type != BundlePriceType.gems) {
        errors.add('price.compareGems only valid on gem-priced bundle');
      } else if (p.gemCost == null || p.compareGems! <= p.gemCost!) {
        errors.add('price.compareGems must be greater than gemCost');
      }
    }
    // 6b. compareUsd requires a valid usdEquivalent on an IAP bundle.
    if (p.compareUsd != null) {
      if (p.type != BundlePriceType.iap) {
        errors.add('price.compareUsd only valid on IAP bundle');
      } else if (p.usdEquivalent == null ||
          p.compareUsd! <= p.usdEquivalent!) {
        errors.add('price.compareUsd must be greater than usdEquivalent');
      }
    }

    // 7. Asset manifest entries non-empty
    for (var i = 0; i < bundle.assetManifest.length; i++) {
      if (bundle.assetManifest[i].trim().isEmpty) {
        errors.add('assetManifest[$i] is empty');
      }
    }

    // 8. Prerequisite values type-checked
    for (var i = 0; i < bundle.prerequisites.length; i++) {
      final pr = bundle.prerequisites[i];
      if (pr.hasUnknownType) {
        errors.add(
          'prerequisites[$i].type "${pr.rawType}" is not a known prerequisite',
        );
      }
      switch (pr.type) {
        case PrerequisiteType.minLevel:
        case PrerequisiteType.completedWorld:
          if (pr.value is! int) {
            errors.add('prerequisites[$i] (${pr.type.jsonValue}) needs int');
          }
          break;
        case PrerequisiteType.minSpend:
          if (pr.value is! num) {
            errors.add('prerequisites[$i] (min_spend) needs number');
          }
          break;
        case PrerequisiteType.ownsJet:
          if (pr.value is! String || (pr.value as String).isEmpty) {
            errors.add('prerequisites[$i] (owns_jet) needs jetId string');
          }
          break;
      }
    }

    // 9. Experiment key format
    final ek = bundle.experimentKey;
    if (ek != null && ek.isNotEmpty && !_experimentKeyPattern.hasMatch(ek)) {
      errors.add('experimentKey format must match ^[a-z0-9_]+\$');
    }

    // 10. purchaseLimit / cooldownAfterPurchaseHours sanity. A
    // purchaseLimit of 0 makes the bundle permanently invisible (live-
    // ops bug); a negative cooldown makes the cooldown gate evaluate
    // as already-elapsed (the opposite of intent).
    if (bundle.purchaseLimit != null && bundle.purchaseLimit! <= 0) {
      errors.add('purchaseLimit must be > 0 when present');
    }
    if (bundle.cooldownAfterPurchaseHours != null &&
        bundle.cooldownAfterPurchaseHours! < 0) {
      errors.add('cooldownAfterPurchaseHours must be >= 0 when present');
    }

    if (errors.isEmpty) return ValidationResult.valid;
    _log(bundle.id.isEmpty ? '<no-id>' : bundle.id, errors);
    return ValidationResult.invalid(errors);
  }

  /// Filters a list of bundles down to those that pass [validate]. Failures
  /// are dropped silently (and logged) — never surfaced to the player.
  List<ShopBundle> filterValid(Iterable<ShopBundle> bundles) {
    final out = <ShopBundle>[];
    for (final b in bundles) {
      if (validate(b).isValid) {
        out.add(b);
      }
    }
    if (kDebugMode) {
      // ignore: avoid_print
      print('[BUNDLE_VALIDATION] ${bundles.length} input → ${out.length} valid');
    }
    return out;
  }
}
