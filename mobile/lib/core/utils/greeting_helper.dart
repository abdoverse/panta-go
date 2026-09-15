import 'dart:math';

/// Represents time-of-day periods for context-aware user greetings.
enum TimeOfDayPeriod {
  morning, // 05:00 - 11:59
  afternoon, // 12:00 - 16:59
  evening, // 17:00 - 21:59
  night, // 22:00 - 04:59
}

class GreetingHelper {
  static final Random _random = Random();

  /// Resolves the current time-of-day period based on hour.
  static TimeOfDayPeriod getTimeOfDayPeriod([DateTime? dateTime]) {
    final dt = dateTime ?? DateTime.now();
    final hour = dt.hour;
    if (hour >= 5 && hour < 12) {
      return TimeOfDayPeriod.morning;
    } else if (hour >= 12 && hour < 17) {
      return TimeOfDayPeriod.afternoon;
    } else if (hour >= 17 && hour < 22) {
      return TimeOfDayPeriod.evening;
    } else {
      return TimeOfDayPeriod.night;
    }
  }

  /// Formats user name for greeting display (uses first name if multi-word).
  static String? formatGreetingName(String? name) {
    if (name == null) return null;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.first;
  }

  /// Returns the pool of greeting variations for the given period and language.
  static List<String> getGreetingPool(
    TimeOfDayPeriod period, {
    required bool isSwedish,
    String? name,
  }) {
    final cleanName = formatGreetingName(name);
    final hasName = cleanName != null && cleanName.isNotEmpty;

    if (isSwedish) {
      switch (period) {
        case TimeOfDayPeriod.morning:
          return [
            hasName ? 'God morgon, $cleanName!' : 'God morgon!',
            hasName ? 'Trevlig morgon, $cleanName!' : 'Trevlig morgon!',
            hasName ? 'Fin morgon för att panta, $cleanName!' : 'Fin morgon för att panta!',
            hasName ? 'Börja dagen grönt, $cleanName!' : 'Börja dagen grönt!',
            hasName ? 'Välkommen tillbaka, $cleanName!' : 'Välkommen tillbaka!',
          ];
        case TimeOfDayPeriod.afternoon:
          return [
            hasName ? 'God eftermiddag, $cleanName!' : 'God eftermiddag!',
            hasName ? 'Hoppas din dag är fin, $cleanName!' : 'Hoppas din dag är fin!',
            hasName ? 'Redo att panta idag, $cleanName?' : 'Redo att panta idag?',
            hasName ? 'Dags för lite återvinning, $cleanName!' : 'Dags för lite återvinning!',
            hasName ? 'Välkommen tillbaka, $cleanName!' : 'Välkommen tillbaka!',
          ];
        case TimeOfDayPeriod.evening:
          return [
            hasName ? 'God kväll, $cleanName!' : 'God kväll!',
            hasName ? 'Avsluta dagen grönt, $cleanName!' : 'Avsluta dagen grönt!',
            hasName ? 'Fin kväll att panta på, $cleanName!' : 'Fin kväll att panta på!',
            hasName ? 'Trevlig kväll, $cleanName!' : 'Trevlig kväll!',
            hasName ? 'Välkommen tillbaka, $cleanName!' : 'Välkommen tillbaka!',
          ];
        case TimeOfDayPeriod.night:
          return [
            hasName ? 'God natt, $cleanName!' : 'God natt!',
            hasName ? 'Sen återvinningskväll, $cleanName?' : 'Sen återvinningskväll?',
            hasName ? 'Nattuggla på språng, $cleanName!' : 'Nattuggla på språng!',
            hasName ? 'Lugna timmar, gröna vanor, $cleanName!' : 'Lugna timmar, gröna vanor!',
            hasName ? 'Välkommen tillbaka, $cleanName!' : 'Välkommen tillbaka!',
          ];
      }
    } else {
      switch (period) {
        case TimeOfDayPeriod.morning:
          return [
            hasName ? 'Good morning, $cleanName!' : 'Good morning!',
            hasName ? 'Rise and shine, $cleanName!' : 'Rise and shine!',
            hasName ? 'Great morning to recycle, $cleanName!' : 'Great morning to recycle!',
            hasName ? 'Start your day green, $cleanName!' : 'Start your day green!',
            hasName ? 'Welcome back, $cleanName!' : 'Welcome back!',
          ];
        case TimeOfDayPeriod.afternoon:
          return [
            hasName ? 'Good afternoon, $cleanName!' : 'Good afternoon!',
            hasName ? 'Hope your day is going well, $cleanName!' : 'Hope your day is going well!',
            hasName ? 'Ready to recycle today, $cleanName?' : 'Ready to recycle today?',
            hasName ? 'Time for some recycling, $cleanName!' : 'Time for some recycling!',
            hasName ? 'Welcome back, $cleanName!' : 'Welcome back!',
          ];
        case TimeOfDayPeriod.evening:
          return [
            hasName ? 'Good evening, $cleanName!' : 'Good evening!',
            hasName ? 'Wrapping up the day green, $cleanName!' : 'Wrapping up the day green!',
            hasName ? 'Great evening to recycle, $cleanName!' : 'Great evening to recycle!',
            hasName ? 'Have a wonderful evening, $cleanName!' : 'Have a wonderful evening!',
            hasName ? 'Welcome back, $cleanName!' : 'Welcome back!',
          ];
        case TimeOfDayPeriod.night:
          return [
            hasName ? 'Good night, $cleanName!' : 'Good night!',
            hasName ? 'Late night recycling, $cleanName?' : 'Late night recycling?',
            hasName ? 'Night owl mode, $cleanName!' : 'Night owl mode!',
            hasName ? 'Quiet hours, green habits, $cleanName!' : 'Quiet hours, green habits!',
            hasName ? 'Welcome back, $cleanName!' : 'Welcome back!',
          ];
      }
    }
  }

  /// Selects a greeting based on time of day, language, and optional variation index.
  static String getGreeting({
    required bool isSwedish,
    String? name,
    DateTime? dateTime,
    int? variationIndex,
  }) {
    final period = getTimeOfDayPeriod(dateTime);
    final pool = getGreetingPool(period, isSwedish: isSwedish, name: name);
    final index = variationIndex != null
        ? (variationIndex % pool.length).abs()
        : _random.nextInt(pool.length);
    return pool[index];
  }
}
