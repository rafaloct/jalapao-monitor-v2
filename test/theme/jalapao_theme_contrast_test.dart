import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jalapao_monitor/theme/jalapao_theme.dart';
import 'package:jalapao_monitor/theme/place_type_style.dart';
import 'package:material_ui/material_ui.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// Razão de contraste WCAG 2.x entre duas cores opacas.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const aaText = 4.5; // WCAG AA — texto normal
  const aaGraphic = 3.0; // WCAG AA — bordas/ícones

  final textTokens = <String, Color>{
    'textPrimary': JalapaoTheme.textPrimary,
    'textMuted': JalapaoTheme.textMuted,
    'textFaint': JalapaoTheme.textFaint,
    'primaryDeep': JalapaoTheme.primaryDeep,
    'secondaryDeep': JalapaoTheme.secondaryDeep,
    'accentDeep': JalapaoTheme.accentDeep,
    'ok': JalapaoTheme.ok,
    'warn': JalapaoTheme.warn,
    'danger': JalapaoTheme.danger,
    'info': JalapaoTheme.info,
  };

  group('fieldHighContrast — texto ≥ 4.5:1', () {
    for (final entry in textTokens.entries) {
      test('${entry.key} sobre background', () {
        expect(
          contrast(entry.value, JalapaoTheme.background),
          greaterThanOrEqualTo(aaText),
        );
      });
      test('${entry.key} sobre surface', () {
        expect(
          contrast(entry.value, JalapaoTheme.surface),
          greaterThanOrEqualTo(aaText),
        );
      });
    }

    test('onPrimary sobre CTA (primaryDeep) e estados', () {
      for (final fill in [
        JalapaoTheme.primaryDeep,
        JalapaoTheme.secondaryDeep,
        JalapaoTheme.ok,
        JalapaoTheme.warn,
        JalapaoTheme.danger,
        JalapaoTheme.info,
      ]) {
        expect(
          contrast(JalapaoTheme.onPrimary, fill),
          greaterThanOrEqualTo(aaText),
          reason: 'fill $fill',
        );
      }
    });

    test('cores por tipo de local sobre background', () {
      for (final c in PlaceTypeStyle.allColors) {
        expect(
          contrast(c, JalapaoTheme.background),
          greaterThanOrEqualTo(aaText),
          reason: 'tipo $c',
        );
      }
    });
  });

  group('bordas e ícones ≥ 3:1', () {
    test('outline sobre background e surface', () {
      expect(
        contrast(JalapaoTheme.outline, JalapaoTheme.background),
        greaterThanOrEqualTo(aaGraphic),
      );
      expect(
        contrast(JalapaoTheme.outline, JalapaoTheme.surface),
        greaterThanOrEqualTo(aaGraphic),
      );
    });
  });

  group('occupancyColor', () {
    test('sem limite → info', () {
      expect(JalapaoTheme.occupancyColor(5, 0), JalapaoTheme.info);
    });
    test('limiares 80% / 100%', () {
      expect(JalapaoTheme.occupancyColor(7, 10), JalapaoTheme.ok);
      expect(JalapaoTheme.occupancyColor(8, 10), JalapaoTheme.warn);
      expect(JalapaoTheme.occupancyColor(10, 10), JalapaoTheme.danger);
    });
  });

  test('tema único: botões e ícones com alvo ≥ 48dp', () {
    final theme = JalapaoTheme.themeData;
    expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    expect(theme.visualDensity, VisualDensity.standard);
    final iconMin = theme.iconButtonTheme.style?.minimumSize?.resolve({});
    expect(iconMin, const Size(JalapaoTheme.minTouch, JalapaoTheme.minTouch));
    final btnMin = theme.elevatedButtonTheme.style?.minimumSize?.resolve({});
    expect(btnMin?.height, greaterThanOrEqualTo(JalapaoTheme.minTouch));
  });
}
