import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/services.dart';

void playPlatformDingDongSound() {
  try {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  } catch (_) {}

  // Synthesize an authentic two-tone "Ding-Dong" chime via Web Audio API
  try {
    js.context.callMethod('eval', [r"""
      (function() {
        try {
          var AudioCtx = window.AudioContext || window.webkitAudioContext;
          if (!AudioCtx) return;
          var ctx = new AudioCtx();
          var now = ctx.currentTime;
          
          var o1 = ctx.createOscillator();
          var g1 = ctx.createGain();
          o1.type = 'sine';
          o1.frequency.setValueAtTime(659.25, now);
          g1.gain.setValueAtTime(0.35, now);
          g1.gain.exponentialRampToValueAtTime(0.001, now + 0.55);
          o1.connect(g1);
          g1.connect(ctx.destination);
          o1.start(now);
          o1.stop(now + 0.6);

          var o2 = ctx.createOscillator();
          var g2 = ctx.createGain();
          o2.type = 'sine';
          o2.frequency.setValueAtTime(523.25, now + 0.28);
          g2.gain.setValueAtTime(0.40, now + 0.28);
          g2.gain.exponentialRampToValueAtTime(0.001, now + 0.95);
          o2.connect(g2);
          g2.connect(ctx.destination);
          o2.start(now + 0.28);
          o2.stop(now + 1.0);
        } catch(e) {}
      })();
    """]);
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
