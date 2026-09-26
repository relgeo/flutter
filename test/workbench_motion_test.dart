import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relgeo_flutter/src/ui/workbench_motion.dart';

void main() {
  testWidgets('reduced motion disables workbench transitions', (
    WidgetTester tester,
  ) async {
    Duration? resolvedDuration;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            resolvedDuration = workbenchMotionDuration(
              context,
              const Duration(milliseconds: 150),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolvedDuration, Duration.zero);
  });

  testWidgets('normal motion retains the requested transition duration', (
    WidgetTester tester,
  ) async {
    Duration? resolvedDuration;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: false),
        child: Builder(
          builder: (context) {
            resolvedDuration = workbenchMotionDuration(
              context,
              const Duration(milliseconds: 150),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolvedDuration, const Duration(milliseconds: 150));
  });
}
