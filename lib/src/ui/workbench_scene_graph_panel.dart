import 'package:flutter/material.dart';
import 'workbench_scene_graph.dart';
import 'workbench_visual_profile.dart';

/// Compact, keyboard-readable graph view for the active resolved scene.
class WorkbenchSceneGraphPanel extends StatelessWidget {
  const WorkbenchSceneGraphPanel({
    super.key,
    required this.graph,
    required this.selectedObjectId,
    required this.visualProfile,
    required this.onSelectObject,
    required this.onClose,
  });

  final WorkbenchSceneGraph graph;
  final String? selectedObjectId;
  final WorkbenchVisualProfile visualProfile;
  final ValueChanged<String> onSelectObject;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Dependency graph',
      child: Material(
        color: visualProfile.overlayBackgroundColor,
        elevation: 8,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 280),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
                child: Row(
                  children: [
                    Icon(Icons.account_tree, size: 15, color: visualProfile.accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'DEPENDENCY GRAPH',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: visualProfile.mutedColor,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('close-scene-graph'),
                      tooltip: 'Close dependency graph',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 15),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: graph.nodes.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No resolved objects'),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: graph.nodes.length,
                        itemBuilder: (context, index) {
                          final node = graph.nodes[index];
                          final selected = node.id == selectedObjectId;
                          final dependencyLabel = node.dependencies.isEmpty
                              ? 'no dependencies'
                              : 'depends on ${node.dependencies.join(', ')}';
                          return Semantics(
                            button: true,
                            selected: selected,
                            label: 'Object ${node.id}',
                            value: '${node.type}, $dependencyLabel',
                            onTap: () => onSelectObject(node.id),
                            child: ListTile(
                              dense: true,
                              selected: selected,
                              selectedTileColor: visualProfile.accentSoftColor,
                              title: Text(
                                node.id,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Courier', fontSize: 11),
                              ),
                              subtitle: Text(
                                '${node.type} · $dependencyLabel',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, color: visualProfile.mutedColor),
                              ),
                              onTap: () => onSelectObject(node.id),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
