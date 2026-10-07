import 'package:flutter/material.dart';

/// Header for the CAD workbench shell.
class WorkbenchNavbar extends StatelessWidget {
  const WorkbenchNavbar({
    super.key,
    required this.hasError,
    this.documentName,
    this.documentPath,
    this.documentDirty = false,
    this.toolbar,
  });

  final bool hasError;
  final String? documentName;
  final String? documentPath;
  final bool documentDirty;
  final Widget? toolbar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;
    final statusColor = hasError ? colorScheme.error : colorScheme.tertiary;
    return Container(
      height: toolbar == null ? 44 : 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.hexagon_outlined, color: accent, size: 18),
          const SizedBox(width: 8),
          Text(
            'RelGeo',
            style: TextStyle(
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: accent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'CAD Workbench',
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'v0.5',
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 10,
                color: accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (documentName != null) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Tooltip(
                message: documentPath ?? documentName!,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        documentName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (documentDirty) ...[
                      const SizedBox(width: 5),
                      Tooltip(
                        message: 'Unsaved changes',
                        child: Icon(
                          Icons.circle,
                          size: 7,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (toolbar != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Align(alignment: Alignment.centerLeft, child: toolbar),
              ),
            ),
            const SizedBox(width: 12),
          ] else
            const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  hasError ? 'ERROR' : 'COMPILED OK',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
