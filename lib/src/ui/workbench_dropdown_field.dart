import 'package:flutter/material.dart';

class WorkbenchDropdownField<T> extends StatelessWidget {
  const WorkbenchDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.semanticsLabel,
    required this.semanticsValue,
    required this.semanticsHint,
    required this.backgroundColor,
    required this.borderColor,
    required this.mutedColor,
    required this.accentColor,
    this.icon = Icons.arrow_drop_down,
    this.iconSize = 16,
    this.buttonKey,
    this.semanticsKey,
    this.hint,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String semanticsLabel;
  final String semanticsValue;
  final String semanticsHint;
  final Color backgroundColor;
  final Color borderColor;
  final Color mutedColor;
  final Color accentColor;
  final IconData icon;
  final double iconSize;
  final Key? buttonKey;
  final Key? semanticsKey;
  final Widget? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Semantics(
        key: semanticsKey,
        container: true,
        label: semanticsLabel,
        value: semanticsValue,
        hint: semanticsHint,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            key: buttonKey,
            value: value,
            hint: hint,
            icon: Icon(icon, color: mutedColor, size: iconSize),
            dropdownColor: backgroundColor,
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
            ),
            onChanged: onChanged,
            items: items,
          ),
        ),
      ),
    );
  }
}
