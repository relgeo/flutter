import 'package:flutter/material.dart';

class WorkbenchBoundsBadge extends StatelessWidget {
  const WorkbenchBoundsBadge({
    super.key,
    required this.bounds,
    required this.unit,
    required this.backgroundColor,
    required this.borderColor,
  });

  final Rect bounds;
  final String unit;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('bounds-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        'BOUNDS: (${bounds.left.toStringAsFixed(1)}, '
        '${bounds.top.toStringAsFixed(1)}) → '
        '${(bounds.left + bounds.width).toStringAsFixed(1)}, '
        '${(bounds.top + bounds.height).toStringAsFixed(1)} '
        '[${bounds.width.toStringAsFixed(1)} × '
        '${bounds.height.toStringAsFixed(1)} $unit]',
        style: const TextStyle(
          fontFamily: 'Courier',
          fontSize: 9,
          color: Color(0xFF00FFCC),
        ),
      ),
    );
  }
}
