import 'package:flutter/material.dart';
import 'package:relgeo_flutter/relgeo_flutter.dart';

import '../../ui/keyboard_activatable.dart';
import '../../ui/workbench_motion.dart';
import '../../ui/workbench_visual_profile.dart';

/// Controls the diagnostic overlays and semantic-role visibility filters.
///
/// The toolbar owns only presentation and interaction wiring. Persistence and
/// profile-following state remain in the workbench page.
class WorkbenchOverlayToolbar extends StatelessWidget {
  const WorkbenchOverlayToolbar({
    super.key,
    required this.visualProfile,
    required this.overlay,
    required this.hiddenRoles,
    required this.followProfileOverlay,
    required this.followProfileRoleFilter,
    required this.onFollowProfileOverlayChanged,
    required this.onFollowProfileRoleFilterChanged,
    required this.onOverlayChanged,
    required this.onHiddenRolesChanged,
  });

  final WorkbenchVisualProfile visualProfile;
  final OverlayOptions overlay;
  final Set<String> hiddenRoles;
  final bool followProfileOverlay;
  final bool followProfileRoleFilter;
  final ValueChanged<bool> onFollowProfileOverlayChanged;
  final ValueChanged<bool> onFollowProfileRoleFilterChanged;
  final ValueChanged<OverlayOptions> onOverlayChanged;
  final ValueChanged<Set<String>> onHiddenRolesChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: visualProfile.overlayBackgroundColor,
        border: Border(
          bottom: BorderSide(color: visualProfile.borderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _sectionLabel('IDE OVERLAY'),
              _behaviorSyncChip(
                context,
                key: const Key('overlay-sync-toggle'),
                synced: followProfileOverlay,
                syncedLabel: 'Overlay Sync',
                customLabel: 'Overlay Custom',
                onTap: () =>
                    onFollowProfileOverlayChanged(!followProfileOverlay),
              ),
              _behaviorStatusBadge(
                key: const Key('overlay-status-badge'),
                synced: followProfileOverlay,
                presetLabel: 'Preset Active',
                customLabel: 'Locally Overridden',
              ),
              _overlayToggle(
                context,
                icon: Icons.add_circle_outline,
                label: 'Anchors',
                active: overlay.showAnchors,
                onTap: () => onOverlayChanged(
                  OverlayOptions(
                    showAnchors: !overlay.showAnchors,
                    showLabels: overlay.showLabels,
                    showBoundingBoxes: overlay.showBoundingBoxes,
                  ),
                ),
              ),
              _overlayToggle(
                context,
                icon: Icons.label_outline,
                label: 'Labels',
                active: overlay.showLabels,
                onTap: () => onOverlayChanged(
                  OverlayOptions(
                    showAnchors: overlay.showAnchors,
                    showLabels: !overlay.showLabels,
                    showBoundingBoxes: overlay.showBoundingBoxes,
                  ),
                ),
              ),
              _overlayToggle(
                context,
                icon: Icons.crop_free,
                label: 'BBox',
                active: overlay.showBoundingBoxes,
                onTap: () => onOverlayChanged(
                  OverlayOptions(
                    showAnchors: overlay.showAnchors,
                    showLabels: overlay.showLabels,
                    showBoundingBoxes: !overlay.showBoundingBoxes,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              _sectionLabel('ROLE FILTER'),
              _behaviorSyncChip(
                context,
                key: const Key('role-filter-sync-toggle'),
                synced: followProfileRoleFilter,
                syncedLabel: 'Role Sync',
                customLabel: 'Role Custom',
                onTap: () =>
                    onFollowProfileRoleFilterChanged(!followProfileRoleFilter),
              ),
              _behaviorStatusBadge(
                key: const Key('role-status-badge'),
                synced: followProfileRoleFilter,
                presetLabel: 'Preset Active',
                customLabel: 'Locally Overridden',
              ),
              ...technicalRoles
                  .where((role) => role != 'final')
                  .map((role) => _roleToggle(context, role)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Courier',
        fontSize: 9,
        fontWeight: FontWeight.bold,
        color: visualProfile.mutedColor,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _roleToggle(BuildContext context, String role) {
    final active = !hiddenRoles.contains(role);
    final label = role[0].toUpperCase() + role.substring(1);

    void toggle() {
      final next = Set<String>.from(hiddenRoles);
      if (next.contains(role)) {
        next.remove(role);
      } else {
        next.add(role);
      }
      onHiddenRolesChanged(next);
    }

    return Semantics(
      container: true,
      button: true,
      toggled: active,
      label: '$label role visibility',
      value: active ? 'Visible' : 'Hidden',
      hint: 'Toggle $label visibility',
      child: WorkbenchKeyboardActivatable(
        onActivate: toggle,
        focusColor: visualProfile.accentColor,
        child: GestureDetector(
          onTap: toggle,
          child: AnimatedContainer(
            key: Key('role-toggle-$role'),
            duration: workbenchMotionDuration(
              context,
              const Duration(milliseconds: 150),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: active
                  ? visualProfile.accentSoftColor
                  : visualProfile.toolbarBackgroundColor,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: active
                    ? visualProfile.accentColor
                    : visualProfile.borderColor,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: active
                    ? visualProfile.accentColor
                    : visualProfile.mutedColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayToggle(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Semantics(
      container: true,
      button: true,
      toggled: active,
      label: '$label overlay',
      value: active ? 'Shown' : 'Hidden',
      hint: 'Toggle $label overlay',
      child: WorkbenchKeyboardActivatable(
        onActivate: onTap,
        focusColor: visualProfile.accentColor,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: workbenchMotionDuration(
              context,
              const Duration(milliseconds: 150),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: active
                  ? visualProfile.accentSoftColor
                  : visualProfile.toolbarBackgroundColor,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: active
                    ? visualProfile.accentColor
                    : visualProfile.borderColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 12,
                  color: active
                      ? visualProfile.accentColor
                      : visualProfile.mutedColor,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: active
                        ? visualProfile.accentColor
                        : visualProfile.mutedColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _behaviorSyncChip(
    BuildContext context, {
    required Key key,
    required bool synced,
    required String syncedLabel,
    required String customLabel,
    required VoidCallback onTap,
  }) {
    return Semantics(
      key: key,
      container: true,
      button: true,
      toggled: synced,
      label: synced ? syncedLabel : customLabel,
      value: synced ? 'Following preset' : 'Customized',
      hint: 'Toggle preset synchronization',
      child: WorkbenchKeyboardActivatable(
        onActivate: onTap,
        focusColor: visualProfile.accentColor,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: workbenchMotionDuration(
              context,
              const Duration(milliseconds: 150),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: synced
                  ? visualProfile.accentSoftColor
                  : visualProfile.toolbarBackgroundColor,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: synced
                    ? visualProfile.accentColor
                    : visualProfile.borderColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  synced ? Icons.lock_outline : Icons.tune,
                  size: 12,
                  color: synced
                      ? visualProfile.accentColor
                      : visualProfile.mutedColor,
                ),
                const SizedBox(width: 4),
                Text(
                  synced ? syncedLabel : customLabel,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: synced
                        ? visualProfile.accentColor
                        : visualProfile.mutedColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _behaviorStatusBadge({
    required Key key,
    required bool synced,
    required String presetLabel,
    required String customLabel,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: synced
            ? visualProfile.accentSoftColor
            : visualProfile.borderColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: synced
              ? visualProfile.accentColor.withValues(alpha: 0.5)
              : visualProfile.borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            synced ? Icons.check_circle_outline : Icons.edit_note,
            size: 12,
            color: synced
                ? visualProfile.accentColor
                : visualProfile.mutedColor,
          ),
          const SizedBox(width: 4),
          Text(
            synced ? presetLabel : customLabel,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: synced
                  ? visualProfile.accentColor
                  : visualProfile.mutedColor,
            ),
          ),
        ],
      ),
    );
  }
}
