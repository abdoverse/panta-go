import 'sound_helper_stub.dart'
    if (dart.library.html) 'sound_helper_web.dart';

/// Plays an audible "Ding-Dong" doorbell chime when a Helper marks arrival at the door.
///
/// - On Flutter Web: Uses the browser Web Audio API ([AudioContext]) to synthesize
///   an authentic two-tone doorbell chime (E5 -> C5) with zero asset latency.
///   Also triggers a browser notification if granted.
/// - On Native / Non-Web: Triggers [SystemSound.play] and heavy haptic feedback.
void playDingDongSound() => playPlatformDingDongSound();
