import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_layout_model.dart';

void main() {
  test('standard layout declares all workbench panels and regions', () {
    final layout = WorkbenchLayoutModel.standard();

    expect(layout.schemaVersion, WorkbenchLayoutModel.currentSchemaVersion);
    expect(layout.activeProfileId, WorkbenchLayoutModel.standardProfileId);
    expect(layout.panels.keys, containsAll(WorkbenchPanelId.values));
    expect(
      layout.panels[WorkbenchPanelId.parameters]!.placement,
      WorkbenchPanelPlacement.bottom,
    );
    expect(layout.splitRatios['left'], 0.32);
  });

  test('layout JSON round-trips without losing panel or floating bounds', () {
    final original = WorkbenchLayoutModel.standard(profileId: 'custom')
        .copyWith(
          panels: {
            ...WorkbenchLayoutModel.standard().panels,
            WorkbenchPanelId.inspector: const WorkbenchPanelLayout(
              visibility: WorkbenchPanelVisibility.hidden,
              placement: WorkbenchPanelPlacement.floating,
              bounds: WorkbenchPanelBounds(
                width: 480,
                height: 360,
                left: 32,
                top: 24,
                minWidth: 240,
              ),
            ),
          },
          floatingBounds: const {
            WorkbenchPanelId.inspector: WorkbenchPanelBounds(
              width: 480,
              height: 360,
              left: 32,
              top: 24,
            ),
          },
          floatingOrder: const [WorkbenchPanelId.inspector],
        );

    final restored = WorkbenchLayoutModel.fromJson(original.toJson());
    expect(restored, original);
    expect(restored.floatingOrder, const [WorkbenchPanelId.inspector]);
  });

  test('unknown schema or incomplete panel data falls back to Standard', () {
    final standard = WorkbenchLayoutModel.standard();

    expect(WorkbenchLayoutModel.fromJson({'schemaVersion': 99}), standard);
    expect(
      WorkbenchLayoutModel.fromJson({
        'schemaVersion': WorkbenchLayoutModel.currentSchemaVersion,
        'activeProfileId': 'broken',
        'panels': {},
      }),
      standard,
    );
  });

  test('legacy overlay and collapsed states restore as float and hidden', () {
    final legacy = WorkbenchLayoutModel.standard().toJson();
    final panels = legacy['panels'] as Map<String, Object>;
    final inspector = Map<String, Object>.from(panels['inspector']! as Map);
    inspector['visibility'] = 'collapsed';
    inspector['placement'] = 'overlay';
    panels['inspector'] = inspector;

    final restored = WorkbenchLayoutModel.fromJson(legacy);
    expect(
      restored.panels[WorkbenchPanelId.inspector]!.visibility,
      WorkbenchPanelVisibility.hidden,
    );
    expect(
      restored.panels[WorkbenchPanelId.inspector]!.placement,
      WorkbenchPanelPlacement.floating,
    );
    final serializedPanels = restored.toJson()['panels'] as Map<String, Object>;
    final serializedInspector = serializedPanels['inspector'] as Map;
    expect(serializedInspector['visibility'], 'hidden');
    expect(serializedInspector['placement'], 'floating');
  });

  test('document-derived availability stays outside serialized layout', () {
    final layout = WorkbenchLayoutModel.standard();
    final persisted = layout.toJson();

    expect(persisted['panels'], isNot(contains('availability')));
    expect(WorkbenchPanelAvailability.unavailable, isNotNull);
  });
}
