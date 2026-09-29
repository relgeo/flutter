import 'package:flutter/material.dart';

import 'workbench_commands.dart';

/// Header for the CAD workbench shell.
class WorkbenchNavbar extends StatelessWidget {
  const WorkbenchNavbar({
    super.key,
    required this.hasError,
    required this.exportButtonLabel,
    required this.onExport,
    this.documentName,
    this.documentPath,
    this.documentDirty = false,
    this.toolbar,
    this.commandRegistry,
  });

  final bool hasError;
  final String exportButtonLabel;
  final VoidCallback onExport;
  final String? documentName;
  final String? documentPath;
  final bool documentDirty;
  final Widget? toolbar;
  final WorkbenchCommandRegistry? commandRegistry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: toolbar == null ? 44 : 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hexagon_outlined,
            color: Color(0xFF00FFCC),
            size: 18,
          ),
          const SizedBox(width: 8),
          const Text(
            'RelGeo',
            style: TextStyle(
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF00FFCC),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'CAD Workbench',
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x1A00FFCC),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'v0.5',
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 10,
                color: Color(0xFF00FFCC),
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
                      const Tooltip(
                        message: 'Unsaved changes',
                        child: Icon(
                          Icons.circle,
                          size: 7,
                          color: Color(0xFFF59E0B),
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
              color: hasError
                  ? const Color(0x1AEF4444)
                  : const Color(0x1A10B981),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: hasError
                    ? const Color(0x55EF4444)
                    : const Color(0x5510B981),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: hasError
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
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
                    color: hasError
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            key: const Key('export-svg-button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
            icon: const Icon(Icons.download, size: 14),
            label: Text(
              exportButtonLabel,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
            onPressed:
                commandRegistry?.find(WorkbenchCommandId.exportSvg)?.invoke ??
                onExport,
          ),
        ],
      ),
    );
  }
}
