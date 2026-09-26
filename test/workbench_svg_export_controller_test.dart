import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_svg_export_controller.dart';

void main() {
  test('saves SVG through the injected native boundary', () async {
    String? writtenPath;
    String? writtenContents;
    final controller = WorkbenchSvgExportController(
      pickFile: ({required dialogTitle, required fileName}) async =>
          '/tmp/$fileName',
      writeFile: (path, contents) async {
        writtenPath = path;
        writtenContents = contents;
      },
    );

    final result = await controller.saveSvg(
      dialogTitle: 'Export',
      fileName: 'drawing.svg',
      svg: '<svg />',
    );

    expect(result, '/tmp/drawing.svg');
    expect(writtenPath, '/tmp/drawing.svg');
    expect(writtenContents, '<svg />');
  });

  test('does not write when the user cancels the picker', () async {
    var writeCount = 0;
    final controller = WorkbenchSvgExportController(
      pickFile: ({required dialogTitle, required fileName}) async => null,
      writeFile: (path, contents) async {
        expect(path, isNotEmpty);
        expect(contents, isNotEmpty);
        writeCount++;
      },
    );

    final result = await controller.saveSvg(
      dialogTitle: 'Export',
      fileName: 'drawing.svg',
      svg: '<svg />',
    );

    expect(result, isNull);
    expect(writeCount, 0);
  });
}
