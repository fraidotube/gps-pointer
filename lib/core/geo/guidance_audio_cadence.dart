abstract final class GuidanceAudioCadence {
  static Duration intervalFor(double absoluteErrorDegrees) {
    if (!absoluteErrorDegrees.isFinite || absoluteErrorDegrees < 0) {
      throw ArgumentError.value(absoluteErrorDegrees, 'absoluteErrorDegrees');
    }
    if (absoluteErrorDegrees > 30) return const Duration(milliseconds: 1400);
    if (absoluteErrorDegrees > 15) return const Duration(milliseconds: 1000);
    if (absoluteErrorDegrees > 7) return const Duration(milliseconds: 700);
    if (absoluteErrorDegrees > 3) return const Duration(milliseconds: 450);
    return const Duration(milliseconds: 250);
  }
}
