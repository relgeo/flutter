import 'package:flutter/foundation.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

import '../../ui/relgeo_theme_extension.dart';
import '../../ui/workbench_visual_profile.dart';

/// Composition-facing snapshot for the inspector feature.
class WorkbenchInspectorContract {
  const WorkbenchInspectorContract({
    required this.scene,
    required this.yamlError,
    required this.compilerError,
    required this.targetUnit,
    required this.visualProfile,
    required this.themeTokens,
    this.selectedObjectId,
    this.onSelectObject,
  });

  final ResolvedScene? scene;
  final String? yamlError;
  final String? compilerError;
  final String targetUnit;
  final WorkbenchVisualProfile visualProfile;
  final RelGeoThemeExtension? themeTokens;
  final String? selectedObjectId;
  final ValueChanged<String>? onSelectObject;
}
