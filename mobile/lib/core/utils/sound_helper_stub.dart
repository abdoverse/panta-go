import 'package:flutter/services.dart';

void playPlatformDingDongSound() {
  try {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    HapticFeedback.vibrate();
  } catch (_) {}
}
