import 'package:flutter/material.dart';

import 'workbench_commands.dart';

/// Header for the CAD workbench shell.
class WorkbenchNavbar extends StatelessWidget {
  const WorkbenchNavbar({
    super.key,
    required this.hasError,
    required this.exportButtonLabel,
    required this.onExport,
    this.commandRegistry,
  });

  final bool hasError;
  final String exportButtonLabel;
  final VoidCallback onExport;
  final WorkbenchCommandRegistry? commandRegistry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
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
