import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/app_theme.dart';
import 'package:relgeo_flutter/src/ui/relgeo_theme_extension.dart';
import 'package:relgeo_flutter/src/ui/workbench_visual_profile.dart';

double _linearChannel(double value) {
  return value <= 0.03928
      ? value / 12.92
      : ((value + 0.055) / 1.055) * ((value + 0.055) / 1.055);
}

double _relativeLuminance(Color color) {
  return (0.2126 * _linearChannel(color.r)) +
      (0.7152 * _linearChannel(color.g)) +
      (0.0722 * _linearChannel(color.b));
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = _relativeLuminance(foreground);
  final backgroundLuminance = _relativeLuminance(background);
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('light and dark themes expose RelGeo canvas tokens', () {
    final light = buildRelGeoLightTheme();
    final dark = buildRelGeoDarkTheme();

    final lightTokens = light.extension<RelGeoThemeExtension>();
    final darkTokens = dark.extension<RelGeoThemeExtension>();

    expect(lightTokens, isNotNull);
    expect(darkTokens, isNotNull);
    expect(lightTokens!.roleColor('final'), isNotNull);
    expect(darkTokens!.roleColor('construction'), isNotNull);
    expect(
      lightTokens.canvasBackgroundColor,
      isNot(equals(darkTokens.canvasBackgroundColor)),
    );
  });

  test('theme extension lerp preserves role token map', () {
    final source = buildRelGeoLightTheme().extension<RelGeoThemeExtension>()!;
    final target = buildRelGeoDarkTheme().extension<RelGeoThemeExtension>()!;

    final midpoint = source.lerp(target, 0.5);

    expect(midpoint.roleColors, same(target.roleColors));
    expect(midpoint.canvasBackgroundColor, isNot(source.canvasBackgroundColor));
  });

  test('visual profile separates canvas appearance from behavior preset', () {
    final profile = WorkbenchVisualProfile.paper;

    expect(
      profile.canvasAppearance.viewportBackgroundColor,
      profile.viewportBackgroundColor,
    );
    expect(
      profile.canvasAppearance.roleColor('final'),
      profile.roleColor('final'),
    );
    expect(profile.behavior.baseGridWorldStep, 25.0);
    expect(profile.behavior.hiddenRoles, contains('construction'));
  });

  test('core canvas text and diagnostic tokens meet contrast baselines', () {
    for (final theme in [buildRelGeoLightTheme(), buildRelGeoDarkTheme()]) {
      final tokens = theme.extension<RelGeoThemeExtension>()!;

      expect(
        _contrastRatio(tokens.canvasTextColor, tokens.canvasBackgroundColor),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          tokens.canvasMutedTextColor,
          tokens.canvasBackgroundColor,
        ),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrastRatio(tokens.diagnosticColor, tokens.canvasBackgroundColor),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrastRatio(tokens.selectedColor, tokens.canvasBackgroundColor),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrastRatio(tokens.errorColor, tokens.canvasBackgroundColor),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrastRatio(tokens.successColor, tokens.canvasBackgroundColor),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrastRatio(tokens.warningColor, tokens.canvasBackgroundColor),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrastRatio(tokens.disabledColor, tokens.canvasBackgroundColor),
        greaterThanOrEqualTo(2.0),
      );
    }
  });
}
