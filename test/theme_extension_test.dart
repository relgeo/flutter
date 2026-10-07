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
  test('application brightness selects the matching canvas palette', () {
    final light = buildRelGeoLightTheme();
    final dark = buildRelGeoDarkTheme();

    final lightTokens = light.extension<RelGeoThemeExtension>();
    final darkTokens = dark.extension<RelGeoThemeExtension>();

    expect(lightTokens, isNotNull);
    expect(darkTokens, isNotNull);
    expect(lightTokens!.roleColor('final'), isNotNull);
    expect(darkTokens!.roleColor('construction'), isNotNull);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(
      lightTokens.canvasBackgroundColor,
      isNot(darkTokens.canvasBackgroundColor),
    );
  });

  test('all visual profiles have light and dark canvas palettes', () {
    for (final profile in WorkbenchVisualProfile.all) {
      final light = buildRelGeoLightTheme(profile: profile);
      final dark = buildRelGeoDarkTheme(profile: profile);
      final lightTokens = light.extension<RelGeoThemeExtension>()!;
      final darkTokens = dark.extension<RelGeoThemeExtension>()!;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(
        lightTokens.canvasBackgroundColor,
        profile.appearanceFor(Brightness.light).viewportBackgroundColor,
      );
      expect(
        darkTokens.canvasBackgroundColor,
        profile.appearanceFor(Brightness.dark).viewportBackgroundColor,
      );
      expect(
        lightTokens.canvasBackgroundColor,
        isNot(darkTokens.canvasBackgroundColor),
      );
      expect(
        lightTokens.roleColors,
        profile.appearanceFor(Brightness.light).roleColors,
      );
      expect(
        darkTokens.roleColors,
        profile.appearanceFor(Brightness.dark).roleColors,
      );
      expect(light.colorScheme.primary, isNot(Colors.transparent));
      expect(dark.colorScheme.primary, isNot(Colors.transparent));
    }
  });

  test('app brightness adapts chrome and canvas palette together', () {
    for (final profile in WorkbenchVisualProfile.all) {
      final lightScheme = buildRelGeoLightTheme(profile: profile).colorScheme;
      final darkScheme = buildRelGeoDarkTheme(profile: profile).colorScheme;
      final lightChrome = profile.withChromeTheme(lightScheme);
      final darkChrome = profile.withChromeTheme(darkScheme);

      expect(
        lightChrome.viewportBackgroundColor,
        profile.appearanceFor(Brightness.light).viewportBackgroundColor,
      );
      expect(
        darkChrome.viewportBackgroundColor,
        profile.appearanceFor(Brightness.dark).viewportBackgroundColor,
      );
      expect(
        lightChrome.gridMinorColor,
        profile.appearanceFor(Brightness.light).gridMinorColor,
      );
      expect(
        darkChrome.gridMinorColor,
        profile.appearanceFor(Brightness.dark).gridMinorColor,
      );
      expect(lightChrome.toolbarBackgroundColor, lightScheme.surface);
      expect(darkChrome.toolbarBackgroundColor, darkScheme.surface);
      expect(lightChrome.mutedColor, lightScheme.onSurfaceVariant);
      expect(darkChrome.mutedColor, darkScheme.onSurfaceVariant);
      expect(
        lightChrome.roleColors,
        profile.appearanceFor(Brightness.light).roleColors,
      );
      expect(
        darkChrome.roleColors,
        profile.appearanceFor(Brightness.dark).roleColors,
      );
    }
  });

  test('theme extension lerp preserves role token map', () {
    final source = buildRelGeoLightTheme(
      profile: WorkbenchVisualProfile.paper,
    ).extension<RelGeoThemeExtension>()!;
    final target = buildRelGeoDarkTheme(
      profile: WorkbenchVisualProfile.blueprint,
    ).extension<RelGeoThemeExtension>()!;

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

  test(
    'canvas text, diagnostics, and grid keep contrast in all combinations',
    () {
      for (final profile in WorkbenchVisualProfile.all) {
        for (final theme in [
          buildRelGeoLightTheme(profile: profile),
          buildRelGeoDarkTheme(profile: profile),
        ]) {
          final tokens = theme.extension<RelGeoThemeExtension>()!;

          expect(
            _contrastRatio(
              tokens.canvasTextColor,
              tokens.canvasBackgroundColor,
            ),
            greaterThanOrEqualTo(4.5),
            reason: '${profile.id} ${theme.brightness} canvas text',
          );
          expect(
            _contrastRatio(
              tokens.canvasMutedTextColor,
              tokens.canvasBackgroundColor,
            ),
            greaterThanOrEqualTo(3.0),
          );
          expect(
            _contrastRatio(
              tokens.diagnosticColor,
              tokens.canvasBackgroundColor,
            ),
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
          expect(
            _contrastRatio(tokens.gridMinorColor, tokens.canvasBackgroundColor),
            greaterThanOrEqualTo(1.15),
          );
          expect(
            _contrastRatio(tokens.gridMajorColor, tokens.canvasBackgroundColor),
            greaterThanOrEqualTo(1.4),
          );
        }
      }
    },
  );
}
