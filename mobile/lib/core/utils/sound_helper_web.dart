import 'dart:html' as html;
import 'package:flutter/services.dart';

void playPlatformDingDongSound() {
  try {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  } catch (_) {}

  // Synthesize an authentic two-tone "Ding-Dong" chime via Web Audio API
  try {
    final audioContext = html.AudioContext();
    final now = audioContext.currentTime ?? 0.0;

    // --- "Ding" (E5 note ~ 659.25 Hz) ---
    final osc1 = audioContext.createOscillator();
    final gain1 = audioContext.createGain();
    osc1.type = 'sine';
    osc1.frequency?.value = 659.25;

    gain1.gain?.setValueAtTime(0.35, now);
    gain1.gain?.exponentialRampToValueAtTime(0.001, now + 0.55);

    osc1.connect(gain1);
    gain1.connect(audioContext.destination);

    osc1.start(now);
    osc1.stop(now + 0.6);

    // --- "Dong" (C5 note ~ 523.25 Hz, slightly lower pitch and longer decay) ---
    final osc2 = audioContext.createOscillator();
    final gain2 = audioContext.createGain();
    osc2.type = 'sine';
    osc2.frequency?.value = 523.25;

    gain2.gain?.setValueAtTime(0.40, now + 0.28);
    gain2.gain?.exponentialRampToValueAtTime(0.001, now + 0.95);

    osc2.connect(gain2);
    gain2.connect(audioContext.destination);

    osc2.start(now + 0.28);
    osc2.stop(now + 1.0);
  } catch (_) {}

  // Display browser notification if permitted (great for background tabs)
  try {
    if (html.Notification.permission == 'granted') {
      html.Notification(
        'Ding-Dong! Helper is at your door 🛎️',
        body: 'Your helper has arrived for your recycling pickup.',
        icon: 'icons/Icon-192.png',
      );
    }
  } catch (_) {}
}
