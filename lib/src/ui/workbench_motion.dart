import 'package:flutter/widgets.dart';

/// Returns a normal motion duration unless the platform requests reduced
/// motion, in which case the transition completes immediately.
Duration workbenchMotionDuration(BuildContext context, Duration duration) {
  return MediaQuery.maybeOf(context)?.disableAnimations == true
      ? Duration.zero
      : duration;
}
