import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panta/core/localization/app_localizations.dart';
import 'package:panta/core/utils/greeting_helper.dart';

void main() {
  group('Dynamic & Time-Aware User Greetings (Item 18)', () {
    test('getTimeOfDayPeriod correctly maps 24-hour cycle to periods', () {
      // Morning: 05:00 - 11:59
      expect(GreetingHelper.getTimeOfDayPeriod(DateTime(2026, 9, 15, 5, 0)),
          TimeOfDayPeriod.morning);
      expect(GreetingHelper.getTimeOfDayPeriod(DateTime(2026, 9, 15, 8, 30)),
          TimeOfDayPeriod.morning);
      expect(GreetingHelper.getTimeOfDayPeriod(DateTime(2026, 9, 15, 11, 59)),
          TimeOfDayPeriod.morning);

      // Afternoon: 12:00 - 16:59
      expect(GreetingHelper.getTimeOfDayPeriod(DateTime(2026, 9, 15, 12, 0)),
          TimeOfDayPeriod.afternoon);
      expect(GreetingHelper.getTimeOfDayPeriod(DateTime(2026, 9, 15, 14, 30)),
          TimeOfDayPeriod.afternoon);
      expect(GreetingHelper.getTimeOfDayPeriod(DateTime(2026, 9, 15, 16, 59)),
          TimeOfDayPeriod.afternoon);

      // Evening: 17:00 - 21:59
      expect(GreetingHelper.getTimeOfDayPeriod(DateTime(2026, 9, 15, 17, 0)),
          TimeOfDayPeriod.evening);
      expect(GreetingHelper.getTimeOfDayPeriod(DateTime(2026, 9, 15, 19, 45)),
          TimeOfDayPeriod.evening);
      expect(GreetingHelper.getTimeOfDayPeriod(DateTime(2026, 9, 15, 21, 59)),
          TimeOfDayPeriod.evening);

      // Night: 22:00 - 04:59
      expect(GreetingHelper.getTimeOfDayPeriod(DateTime(2026, 9, 15, 22, 0)),
          TimeOfDayPeriod.night);
      expect(GreetingHelper.getTimeOfDayPeriod(DateTime(2026, 9, 15, 0, 0)),
          TimeOfDayPeriod.night);
      expect(GreetingHelper.getTimeOfDayPeriod(DateTime(2026, 9, 15, 2, 30)),
          TimeOfDayPeriod.night);
      expect(GreetingHelper.getTimeOfDayPeriod(DateTime(2026, 9, 15, 4, 59)),
          TimeOfDayPeriod.night);
    });

    test('formatGreetingName extracts clean first name or returns null', () {
      expect(GreetingHelper.formatGreetingName(null), isNull);
      expect(GreetingHelper.formatGreetingName(''), isNull);
      expect(GreetingHelper.formatGreetingName('   '), isNull);
      expect(GreetingHelper.formatGreetingName('Anna'), 'Anna');
      expect(GreetingHelper.formatGreetingName('Anna Larsson'), 'Anna');
      expect(GreetingHelper.formatGreetingName('  Erik   Johansson  '), 'Erik');
      expect(GreetingHelper.formatGreetingName('Karl-Johan'), 'Karl-Johan');
    });

    test('English greeting pools contain rich variations for all periods', () {
      for (final period in TimeOfDayPeriod.values) {
        final withName = GreetingHelper.getGreetingPool(
          period,
          isSwedish: false,
          name: 'Anna',
        );
        expect(withName.length, greaterThanOrEqualTo(4));
        for (final greeting in withName) {
          expect(greeting, contains('Anna'));
        }

        final withoutName = GreetingHelper.getGreetingPool(
          period,
          isSwedish: false,
          name: null,
        );
        expect(withoutName.length, greaterThanOrEqualTo(4));
        for (final greeting in withoutName) {
          expect(greeting, isNotEmpty);
          expect(greeting, isNot(contains('null')));
        }
      }

      // Period-specific checks (EN)
      final morning = GreetingHelper.getGreeting(
        isSwedish: false,
        name: 'Anna',
        dateTime: DateTime(2026, 9, 15, 9, 0),
        variationIndex: 0,
      );
      expect(morning, 'Good morning, Anna!');

      final afternoon = GreetingHelper.getGreeting(
        isSwedish: false,
        name: 'Anna',
        dateTime: DateTime(2026, 9, 15, 13, 0),
        variationIndex: 0,
      );
      expect(afternoon, 'Good afternoon, Anna!');

      final evening = GreetingHelper.getGreeting(
        isSwedish: false,
        name: 'Anna',
        dateTime: DateTime(2026, 9, 15, 18, 0),
        variationIndex: 0,
      );
      expect(evening, 'Good evening, Anna!');

      final night = GreetingHelper.getGreeting(
        isSwedish: false,
        name: 'Anna',
        dateTime: DateTime(2026, 9, 15, 23, 0),
        variationIndex: 0,
      );
      expect(night, 'Good night, Anna!');
    });

    test('Swedish greeting pools contain authentic localized variations for all periods', () {
      for (final period in TimeOfDayPeriod.values) {
        final withName = GreetingHelper.getGreetingPool(
          period,
          isSwedish: true,
          name: 'Erik',
        );
        expect(withName.length, greaterThanOrEqualTo(4));
        for (final greeting in withName) {
          expect(greeting, contains('Erik'));
        }

        final withoutName = GreetingHelper.getGreetingPool(
          period,
          isSwedish: true,
          name: null,
        );
        expect(withoutName.length, greaterThanOrEqualTo(4));
        for (final greeting in withoutName) {
          expect(greeting, isNotEmpty);
          expect(greeting, isNot(contains('null')));
        }
      }

      // Period-specific checks (SV)
      final morning = GreetingHelper.getGreeting(
        isSwedish: true,
        name: 'Erik',
        dateTime: DateTime(2026, 9, 15, 8, 0),
        variationIndex: 0,
      );
      expect(morning, 'God morgon, Erik!');

      final afternoon = GreetingHelper.getGreeting(
        isSwedish: true,
        name: 'Erik',
        dateTime: DateTime(2026, 9, 15, 14, 0),
        variationIndex: 0,
      );
      expect(afternoon, 'God eftermiddag, Erik!');

      final evening = GreetingHelper.getGreeting(
        isSwedish: true,
        name: 'Erik',
        dateTime: DateTime(2026, 9, 15, 20, 0),
        variationIndex: 0,
      );
      expect(evening, 'God kväll, Erik!');

      final night = GreetingHelper.getGreeting(
        isSwedish: true,
        name: 'Erik',
        dateTime: DateTime(2026, 9, 15, 1, 0),
        variationIndex: 0,
      );
      expect(night, 'God natt, Erik!');
    });

    test('variationIndex provides deterministic rotation across variations', () {
      final morningDt = DateTime(2026, 9, 15, 9, 0);
      final pool = GreetingHelper.getGreetingPool(
        TimeOfDayPeriod.morning,
        isSwedish: true,
        name: 'Anna',
      );

      for (int i = 0; i < pool.length; i++) {
        final greeting = GreetingHelper.getGreeting(
          isSwedish: true,
          name: 'Anna',
          dateTime: morningDt,
          variationIndex: i,
        );
        expect(greeting, pool[i]);
      }

      // Wraps around when index >= pool.length
      final wrappedGreeting = GreetingHelper.getGreeting(
        isSwedish: true,
        name: 'Anna',
        dateTime: morningDt,
        variationIndex: pool.length,
      );
      expect(wrappedGreeting, pool[0]);
    });

    test('AppLocalizations integration routes dynamicGreeting and welcomeBack seamlessly', () {
      final l10nSv = AppLocalizations(const Locale('sv', 'SE'));
      final l10nEn = AppLocalizations(const Locale('en', 'US'));
      final morningDt = DateTime(2026, 9, 15, 8, 0);

      // Swedish
      final svGreeting = l10nSv.dynamicGreeting('Anna', morningDt, 0);
      expect(svGreeting, 'God morgon, Anna!');
      expect(l10nSv.welcomeBack('Anna', morningDt, 0), 'God morgon, Anna!');
      expect(l10nSv.dynamicGreeting(), isNotEmpty);
      expect(l10nSv.welcomeBack('Anna'), contains('Anna'));

      // English
      final enGreeting = l10nEn.dynamicGreeting('Anna', morningDt, 0);
      expect(enGreeting, 'Good morning, Anna!');
      expect(l10nEn.welcomeBack('Anna', morningDt, 0), 'Good morning, Anna!');
      expect(l10nEn.dynamicGreeting(), isNotEmpty);
      expect(l10nEn.welcomeBack('Anna'), contains('Anna'));
    });
  });
}
