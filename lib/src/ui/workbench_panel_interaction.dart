import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interaction policy supplied by the workbench shell to an injected panel.
/// Features use this boundary to adapt caption controls when docked or
/// floating without owning layout state themselves.
class WorkbenchPanelInteractionScope extends InheritedWidget {
  const WorkbenchPanelInteractionScope({
    super.key,
    required this.isFloating,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
    required super.child,
  });

  final bool isFloating;
  final VoidCallback? onDragStart;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDragCancel;

  static WorkbenchPanelInteractionScope? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WorkbenchPanelInteractionScope>();

  @override
  bool updateShouldNotify(WorkbenchPanelInteractionScope oldWidget) =>
      isFloating != oldWidget.isFloating ||
      onDragStart != oldWidget.onDragStart ||
      onDragUpdate != oldWidget.onDragUpdate ||
      onDragEnd != oldWidget.onDragEnd ||
      onDragCancel != oldWidget.onDragCancel;
}

/// Makes a floating caption background draggable while leaving its buttons
/// with their own tap and keyboard interactions.
class WorkbenchPanelTitleBar extends StatefulWidget {
  const WorkbenchPanelTitleBar({super.key, required this.child});

  final Widget child;

  @override
  State<WorkbenchPanelTitleBar> createState() => _WorkbenchPanelTitleBarState();
}

class _WorkbenchPanelTitleBarState extends State<WorkbenchPanelTitleBar> {
  late final FocusNode _focusNode;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      debugLabel: 'floating-panel-title-bar',
      skipTraversal: true,
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interaction = WorkbenchPanelInteractionScope.maybeOf(context);
    if (interaction?.isFloating != true) return widget.child;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            _dragging) {
          _dragging = false;
          interaction?.onDragCancel?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: GestureDetector(
          key: const Key('floating-panel-titlebar-drag-region'),
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            _dragging = true;
            _focusNode.requestFocus();
            interaction?.onDragStart?.call();
          },
          onPanUpdate: interaction?.onDragUpdate,
          onPanEnd: (_) {
            if (!_dragging) return;
            _dragging = false;
            interaction?.onDragEnd?.call();
          },
          onPanCancel: () {
            if (!_dragging) return;
            _dragging = false;
            interaction?.onDragCancel?.call();
          },
          child: widget.child,
        ),
      ),
    );
  }
}
