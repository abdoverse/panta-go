import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panta/core/localization/app_localizations.dart';
import 'package:panta/features/dashboard/widgets/helper_job_card.dart';
import 'package:panta/features/dashboard/widgets/user_request_card.dart';
import 'package:panta/features/shared/widgets/five_star_rating_display.dart';
import 'package:panta/models/request_model.dart';
import 'package:panta/providers/panta_provider.dart';
import 'package:provider/provider.dart';

Widget _buildTestWidget(Widget child, {Locale locale = const Locale('en')}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => PantaProvider()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('sv')],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleJobWithCoordinates = RecyclingRequest(
    id: 'req-1',
    title: 'Test Pickup',
    imageUrl: '',
    scheduledFrom: DateTime(2026, 9, 15, 10),
    scheduledTo: DateTime(2026, 9, 15, 12),
    location: 'Drottninggatan 10, Stockholm',
    locationLatitude: 59.3326,
    locationLongitude: 18.0649,
    description: 'Bags of cans',
    status: RequestStatus.pickedUp,
    isRated: true,
    rating: 4.0,
    ratingComment: 'Prompt and helpful!',
  );

  group('Item 20 - Restrict Distance-Aware Sorting Indicator to Relevant Contexts', () {
    testWidgets(
        'Pickup History view (isCompleted == true) removes distance-aware sorting indicator',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        HelperJobCard(
          job: sampleJobWithCoordinates,
          isAcceptable: false,
          isCompleted: true,
        ),
      ));
      await tester.pumpAndSettle();

      // The label MUST NOT appear in Pickup History
      expect(
        find.text('Distance-aware sorting is enabled for this pickup.'),
        findsNothing,
      );
    });

    testWidgets(
        'Browsing available jobs (isAcceptable == true, isCompleted == false) displays distance-aware sorting indicator',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        HelperJobCard(
          job: sampleJobWithCoordinates,
          isAcceptable: true,
          isCompleted: false,
        ),
      ));
      await tester.pumpAndSettle();

      // The label MUST appear when browsing available jobs
      expect(
        find.text('Distance-aware sorting is enabled for this pickup.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Active assigned jobs (isAcceptable == false, isCompleted == false) does not display distance-aware sorting indicator',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        HelperJobCard(
          job: sampleJobWithCoordinates,
          isAcceptable: false,
          isCompleted: false,
        ),
      ));
      await tester.pump();

      expect(
        find.text('Distance-aware sorting is enabled for this pickup.'),
        findsNothing,
      );
    });
  });

  group('Item 21 - Visual 5-Star Rating Display in Pickup History', () {
    testWidgets(
        'FiveStarRatingDisplay renders visual 5-star icons with filled, half, and outline stars',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        const FiveStarRatingDisplay(
          rating: 4.0,
          comment: 'Very polite and on time!',
        ),
      ));
      await tester.pumpAndSettle();

      // 4 filled stars, 1 outline star = 5 total star icons
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(1));

      // Score badge and comment
      expect(find.text('4 / 5'), findsOneWidget);
      expect(find.text('Rated 4'), findsOneWidget);
      expect(find.text('"Very polite and on time!"'), findsOneWidget);
    });

    testWidgets(
        'FiveStarRatingDisplay handles 5-star perfect rating',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        const FiveStarRatingDisplay(
          rating: 5.0,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
      expect(find.text('5 / 5'), findsOneWidget);
      expect(find.text('Rated 5'), findsOneWidget);
    });

    testWidgets(
        'HelperJobCard in Pickup History renders FiveStarRatingDisplay and comment',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        HelperJobCard(
          job: sampleJobWithCoordinates,
          isAcceptable: false,
          isCompleted: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Should render the FiveStarRatingDisplay
      expect(find.byType(FiveStarRatingDisplay), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(1));
      expect(find.text('4 / 5'), findsOneWidget);
      expect(find.text('"Prompt and helpful!"'), findsOneWidget);
    });

    testWidgets(
        'UserRequestCard in Pickup History renders FiveStarRatingDisplay when completed and rated',
        (tester) async {
      final completedUserRequest = RecyclingRequest(
        id: 'req-user-1',
        title: 'User Bags Pickup',
        imageUrl: '',
        scheduledFrom: DateTime(2026, 9, 15, 10),
        scheduledTo: DateTime(2026, 9, 15, 12),
        location: 'Kungsgatan 5, Stockholm',
        description: '2 bags of glass bottles',
        status: RequestStatus.pickedUp,
        isRated: true,
        rating: 5.0,
        ratingComment: 'Super fast and great communication!',
      );

      await tester.pumpWidget(_buildTestWidget(
        UserRequestCard(
          request: completedUserRequest,
          isInteractable: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Should render FiveStarRatingDisplay
      expect(find.byType(FiveStarRatingDisplay), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
      expect(find.text('5 / 5'), findsOneWidget);
      expect(find.text('"Super fast and great communication!"'), findsOneWidget);
    });
  });
}
