import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:panta/core/localization/app_localizations.dart';
import 'package:panta/features/shared/widgets/location_actions.dart';

void main() {
  group('LocationActions URI Scheme Resolution', () {
    const testAddress = 'Sveavägen 44, Stockholm';
    final encoded = Uri.encodeComponent(testAddress);

    test('googleMapsNativeUri generates google.navigation: for directions on Android', () {
      final uri = LocationActions.googleMapsNativeUri(
        queryOrDestination: testAddress,
        directions: true,
        platform: TargetPlatform.android,
      );
      expect(uri.scheme, 'google.navigation');
      expect(uri.toString(), 'google.navigation:q=$encoded');
    });

    test('googleMapsNativeUri generates geo:0,0?q= for viewing location on Android', () {
      final uri = LocationActions.googleMapsNativeUri(
        queryOrDestination: testAddress,
        directions: false,
        platform: TargetPlatform.android,
      );
      expect(uri.scheme, 'geo');
      expect(uri.queryParameters['q'], testAddress);
      expect(uri.toString(), 'geo:0,0?q=$encoded');
    });

    test('googleMapsNativeUri generates comgooglemaps:// for iOS', () {
      final directionsUri = LocationActions.googleMapsNativeUri(
        queryOrDestination: testAddress,
        directions: true,
        platform: TargetPlatform.iOS,
      );
      expect(directionsUri.scheme, 'comgooglemaps');
      expect(directionsUri.queryParameters['daddr'], testAddress);
      expect(directionsUri.queryParameters['directionsmode'], 'driving');

      final searchUri = LocationActions.googleMapsNativeUri(
        queryOrDestination: testAddress,
        directions: false,
        platform: TargetPlatform.iOS,
      );
      expect(searchUri.scheme, 'comgooglemaps');
      expect(searchUri.queryParameters['q'], testAddress);
    });

    test('googleMapsWebUri generates web fallback URL', () {
      final directionsWeb = LocationActions.googleMapsWebUri(
        queryOrDestination: testAddress,
        directions: true,
      );
      expect(directionsWeb.scheme, 'https');
      expect(directionsWeb.host, 'www.google.com');
      expect(directionsWeb.path, '/maps/dir/');
      expect(directionsWeb.queryParameters['api'], '1');
      expect(directionsWeb.queryParameters['destination'], testAddress);

      final searchWeb = LocationActions.googleMapsWebUri(
        queryOrDestination: testAddress,
        directions: false,
      );
      expect(searchWeb.path, '/maps/search/');
      expect(searchWeb.queryParameters['api'], '1');
      expect(searchWeb.queryParameters['query'], testAddress);
    });

    test('appleMapsNativeUri generates maps:// scheme', () {
      final directionsUri = LocationActions.appleMapsNativeUri(
        queryOrDestination: testAddress,
        directions: true,
      );
      expect(directionsUri.scheme, 'maps');
      expect(directionsUri.queryParameters['daddr'], testAddress);

      final searchUri = LocationActions.appleMapsNativeUri(
        queryOrDestination: testAddress,
        directions: false,
      );
      expect(searchUri.scheme, 'maps');
      expect(searchUri.queryParameters['q'], testAddress);
    });

    test('appleMapsWebUri generates maps.apple.com web URL', () {
      final directionsWeb = LocationActions.appleMapsWebUri(
        queryOrDestination: testAddress,
        directions: true,
      );
      expect(directionsWeb.scheme, 'https');
      expect(directionsWeb.host, 'maps.apple.com');
      expect(directionsWeb.queryParameters['daddr'], testAddress);
      expect(directionsWeb.queryParameters['dirflg'], 'd');

      final searchWeb = LocationActions.appleMapsWebUri(
        queryOrDestination: testAddress,
        directions: false,
      );
      expect(searchWeb.queryParameters['q'], testAddress);
    });
  });

  group('LocationActions Widget Tests', () {
    Widget buildTestWidget({
      required String address,
      required bool showDirections,
    }) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('sv')],
        home: Scaffold(
          body: LocationActions(
            address: address,
            showDirections: showDirections,
          ),
        ),
      );
    }

    testWidgets('Renders address and hides directions button when showDirections is false', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        address: 'Kungsgatan 10, Stockholm',
        showDirections: false,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Kungsgatan 10, Stockholm'), findsOneWidget);
      expect(find.text('Get directions'), findsNothing);
    });

    testWidgets('Renders directions button and opens chooser when tapped', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        address: 'Vasagatan 15, Stockholm',
        showDirections: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Vasagatan 15, Stockholm'), findsOneWidget);
      expect(find.text('Get directions'), findsOneWidget);

      await tester.tap(find.text('Get directions'));
      await tester.pumpAndSettle();

      // Modal bottom sheet should be presented
      expect(find.text('Choose map for directions'), findsOneWidget);
      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.text('Apple Maps'), findsOneWidget);
    });

    testWidgets('Tapping address row opens map chooser for viewing address', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        address: 'Drottninggatan 22, Stockholm',
        showDirections: false,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Drottninggatan 22, Stockholm'));
      await tester.pumpAndSettle();

      expect(find.text('Choose map app'), findsOneWidget);
      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.text('Apple Maps'), findsOneWidget);
    });
  });
}
