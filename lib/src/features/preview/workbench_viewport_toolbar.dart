import 'package:flutter/material.dart';

import '../../ui/workbench_dropdown_field.dart';
import '../../ui/workbench_commands.dart';
import '../../ui/workbench_icon_button.dart';
import '../../ui/workbench_preferences.dart';
import '../../ui/workbench_visual_profile.dart';
import 'workbench_preview_target.dart';

class WorkbenchViewportToolbar extends StatelessWidget {
  const WorkbenchViewportToolbar({
    super.key,
    required this.visualProfile,
    required this.commandRegistry,
    required this.zoomLevel,
    required this.targetUnitLabel,
    required this.previewRouteLabel,
    required this.workbenchProfileId,
    required this.themePreference,
    this.showPreviewTools = true,
    required this.onWorkbenchProfileChanged,
    required this.onThemePreferenceChanged,
    required this.documentProfileNames,
    required this.activeProfile,
    required this.onProfileChanged,
    required this.previewTargets,
    required this.selectedPreviewTarget,
    required this.onPreviewTargetChanged,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitViewport,
    required this.onResetViewport,
  });

  final WorkbenchVisualProfile visualProfile;
  final WorkbenchCommandRegistry commandRegistry;
  final double zoomLevel;
  final String targetUnitLabel;
  final String previewRouteLabel;
  final String workbenchProfileId;
  final RelGeoThemePreference? themePreference;
  final bool showPreviewTools;
  final ValueChanged<String>? onWorkbenchProfileChanged;
  final ValueChanged<RelGeoThemePreference>? onThemePreferenceChanged;
  final List<String> documentProfileNames;
  final String? activeProfile;
  final ValueChanged<String?> onProfileChanged;
  final List<WorkbenchPreviewTarget> previewTargets;
  final WorkbenchPreviewTarget selectedPreviewTarget;
  final ValueChanged<WorkbenchPreviewTarget> onPreviewTargetChanged;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitViewport;
  final VoidCallback onResetViewport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final nextTheme = isDark
        ? RelGeoThemePreference.light
        : RelGeoThemePreference.dark;
    final nextThemeCommand = isDark
        ? WorkbenchCommandId.lightTheme
        : WorkbenchCommandId.darkTheme;
    final toggleTheme =
        commandRegistry.find(nextThemeCommand)?.invoke ??
        () => onThemePreferenceChanged?.call(nextTheme);

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showPreviewTools)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.blur_circular, color: colorScheme.primary, size: 14),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'VIEWPORT',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.5,
                      color: colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Zoom: ${(zoomLevel * 100).toInt()}% · $targetUnitLabel',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 9,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    previewRouteLabel,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 9,
                      color: selectedPreviewTarget.sheetId != null
                          ? colorScheme.tertiary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        if (showPreviewTools)
          WorkbenchDropdownField<String>(
            semanticsKey: const Key('workbench-profile-semantics'),
            buttonKey: const Key('workbench-profile-selector'),
            value: workbenchProfileId,
            semanticsLabel: 'Canvas appearance',
            semanticsValue: visualProfile.label,
            semanticsHint: 'Choose a canvas appearance preset',
            backgroundColor: colorScheme.surfaceContainerHighest,
            borderColor: colorScheme.outlineVariant,
            mutedColor: colorScheme.onSurfaceVariant,
            accentColor: colorScheme.primary,
            onChanged: (value) {
              if (value != null) onWorkbenchProfileChanged?.call(value);
            },
            items: WorkbenchVisualProfile.all
                .map(
                  (profile) => DropdownMenuItem<String>(
                    value: profile.id,
                    key: Key('workbench-profile-option-${profile.id}'),
                    child: Text(profile.label),
                  ),
                )
                .toList(),
          ),
        Semantics(
          key: const Key('theme-mode-semantics'),
          label: 'Theme mode',
          value: themePreference == null
              ? '${isDark ? 'Dark' : 'Light'} (System)'
              : themePreference!.label,
          hint:
              'Toggle between Light and Dark. Use View, Appearance to follow system appearance.',
          button: true,
          onTap: toggleTheme,
          child: IconButton(
            key: const Key('theme-mode-selector'),
            tooltip: 'Switch to ${nextTheme.label} mode',
            visualDensity: VisualDensity.compact,
            onPressed: toggleTheme,
            icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            color: colorScheme.primary,
          ),
        ),
        if (themePreference != null)
          IconButton(
            key: const Key('theme-mode-reset'),
            tooltip: 'Follow system appearance',
            icon: const Icon(Icons.settings_backup_restore, size: 15),
            color: colorScheme.onSurfaceVariant,
            onPressed: commandRegistry
                .find(WorkbenchCommandId.followSystemTheme)
                ?.invoke,
          ),
        if (documentProfileNames.isNotEmpty)
          WorkbenchDropdownField<String?>(
            value: activeProfile,
            semanticsLabel: 'Document profile',
            semanticsValue: activeProfile ?? 'Default',
            semanticsHint: 'Choose a document profile',
            backgroundColor: colorScheme.surfaceContainerHighest,
            borderColor: colorScheme.outlineVariant,
            mutedColor: colorScheme.onSurfaceVariant,
            accentColor: colorScheme.primary,
            hint: Text(
              'Select Profile',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontFamily: 'Courier',
              ),
            ),
            onChanged: onProfileChanged,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Default'),
              ),
              ...documentProfileNames.map(
                (name) =>
                    DropdownMenuItem<String?>(value: name, child: Text(name)),
              ),
            ],
          ),
        if (showPreviewTools && previewTargets.length > 1)
          WorkbenchDropdownField<WorkbenchPreviewTarget>(
            buttonKey: const Key('preview-target-selector'),
            value: selectedPreviewTarget,
            semanticsLabel: 'Preview target',
            semanticsValue: selectedPreviewTarget.label,
            semanticsHint:
                'Choose model geometry or a sheet/view. Component previews may be added later.',
            backgroundColor: colorScheme.surfaceContainerHighest,
            borderColor: colorScheme.outlineVariant,
            mutedColor: colorScheme.onSurfaceVariant,
            accentColor: colorScheme.primary,
            hint: Text(
              'Preview target',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontFamily: 'Courier',
              ),
            ),
            onChanged: (target) {
              if (target != null) onPreviewTargetChanged(target);
            },
            items: [
              const DropdownMenuItem<WorkbenchPreviewTarget>(
                value: WorkbenchPreviewTarget.model(),
                key: Key('preview-target-model'),
                child: Text('Model'),
              ),
              ...previewTargets
                  .where(
                    (target) => target.kind == WorkbenchPreviewTargetKind.sheet,
                  )
                  .map(
                    (target) => DropdownMenuItem<WorkbenchPreviewTarget>(
                      value: target,
                      key: Key('preview-target-sheet-${target.id}'),
                      child: Text(target.label),
                    ),
                  ),
            ],
          ),
        WorkbenchIconButton(
          Icons.restart_alt,
          'Reset Workbench Preferences',
          commandRegistry.find(WorkbenchCommandId.resetPreferences)?.invoke ??
              () {},
          color: colorScheme.onSurfaceVariant,
          buttonKey: const Key('reset-workbench-preferences'),
        ),
        if (showPreviewTools)
          WorkbenchIconButton(
            Icons.zoom_in,
            'Perbesar',
            commandRegistry.find(WorkbenchCommandId.zoomIn)?.invoke ?? onZoomIn,
          ),
        if (showPreviewTools)
          WorkbenchIconButton(
            Icons.zoom_out,
            'Perkecil',
            commandRegistry.find(WorkbenchCommandId.zoomOut)?.invoke ??
                onZoomOut,
          ),
        if (showPreviewTools)
          WorkbenchIconButton(
            Icons.center_focus_strong,
            'Fit',
            commandRegistry.find(WorkbenchCommandId.fitViewport)?.invoke ??
                onFitViewport,
            color: colorScheme.primary,
          ),
        if (showPreviewTools)
          WorkbenchIconButton(
            Icons.refresh,
            'Reset',
            commandRegistry.find(WorkbenchCommandId.resetViewport)?.invoke ??
                onResetViewport,
          ),
      ],
    );
  }
}
