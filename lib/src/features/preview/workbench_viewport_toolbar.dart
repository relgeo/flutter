import 'package:flutter/material.dart';

import '../../ui/workbench_dropdown_field.dart';
import '../../ui/workbench_commands.dart';
import '../../ui/workbench_icon_button.dart';
import '../../ui/workbench_preferences.dart';
import '../../ui/workbench_visual_profile.dart';

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
    required this.sheetIds,
    required this.selectedSheetId,
    required this.onSheetChanged,
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
  final List<String> sheetIds;
  final String? selectedSheetId;
  final ValueChanged<String?> onSheetChanged;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitViewport;
  final VoidCallback onResetViewport;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              Icon(
                Icons.blur_circular,
                color: visualProfile.accentColor,
                size: 14,
              ),
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
                      color: visualProfile.accentColor,
                    ),
                  ),
                  Text(
                    'Zoom: ${(zoomLevel * 100).toInt()}% · $targetUnitLabel',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 9,
                      color: visualProfile.mutedColor,
                    ),
                  ),
                  Text(
                    previewRouteLabel,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 9,
                      color: selectedSheetId != null
                          ? const Color(0xFF10B981)
                          : visualProfile.mutedColor,
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
            backgroundColor: visualProfile.overlayBackgroundColor,
            borderColor: visualProfile.borderColor,
            mutedColor: visualProfile.mutedColor,
            accentColor: visualProfile.accentColor,
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
              color: visualProfile.accentColor,
            ),
          ),
          if (themePreference != null)
            IconButton(
              key: const Key('theme-mode-reset'),
              tooltip: 'Follow system appearance',
              icon: const Icon(Icons.settings_backup_restore, size: 15),
              color: visualProfile.mutedColor,
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
              backgroundColor: visualProfile.overlayBackgroundColor,
              borderColor: visualProfile.borderColor,
              mutedColor: visualProfile.mutedColor,
              accentColor: visualProfile.accentColor,
              hint: const Text(
                'Select Profile',
                style: TextStyle(
                  color: Color(0xFF64748B),
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
          if (showPreviewTools && sheetIds.isNotEmpty)
            WorkbenchDropdownField<String?>(
              buttonKey: const Key('sheet-selector'),
              value: selectedSheetId,
              semanticsLabel: 'Surface',
              semanticsValue: selectedSheetId ?? 'Model Preview',
              semanticsHint: 'Choose model preview or a sheet view',
              backgroundColor: visualProfile.overlayBackgroundColor,
              borderColor: visualProfile.borderColor,
              mutedColor: visualProfile.mutedColor,
              accentColor: visualProfile.accentColor,
              hint: const Text(
                'Surface',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontFamily: 'Courier',
                ),
              ),
              onChanged: onSheetChanged,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  key: Key('sheet-option-model-preview'),
                  child: Text('Model Preview'),
                ),
                ...sheetIds.map(
                  (id) => DropdownMenuItem<String?>(
                    value: id,
                    key: Key('sheet-option-$id'),
                    child: Text('Sheet/View: $id'),
                  ),
                ),
              ],
            ),
          WorkbenchIconButton(
            Icons.restart_alt,
            'Reset Workbench Preferences',
            commandRegistry.find(WorkbenchCommandId.resetPreferences)?.invoke ??
                () {},
            color: visualProfile.mutedColor,
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
            color: const Color(0xFF00FFCC),
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
