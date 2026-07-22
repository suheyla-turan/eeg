import 'package:flutter/material.dart';

/// Dikey PageView'da yalnızca sonraki sayfaya kaydırmaya izin verir.
class ForwardOnlyScrollPhysics extends PageScrollPhysics {
  const ForwardOnlyScrollPhysics({super.parent});

  @override
  ForwardOnlyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ForwardOnlyScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // Negatif offset = önceki sayfaya doğru; engelle.
    if (offset < 0) return 0;
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Geriye doğru fling'i yok say.
    if (velocity < 0) {
      return super.createBallisticSimulation(position, 0);
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
