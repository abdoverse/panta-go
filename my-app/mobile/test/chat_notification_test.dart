import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panta/core/localization/app_localizations.dart';
import 'package:panta/features/chat/chat_notification_banner.dart';
import 'package:panta/features/dashboard/widgets/helper_job_card.dart';
import 'package:panta/features/dashboard/widgets/user_request_card.dart';
import 'package:panta/models/chat_message.dart';
import 'package:panta/models/request_model.dart';
import 'package:panta/providers/panta_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('In-App Chat Notification System', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('PantaProvider tracks unread messages and incoming banner state for Recycler', () async {
      final provider = PantaProvider();
      await provider.restoreSession();

      // Add a test request
      final now = DateTime.now();
      final req = RecyclingRequest(
        id: 'req-1',
        title: 'Bottles in Stockholm',
        scheduledFrom: now,
        scheduledTo: now.add(const Duration(hours: 1)),
        location: 'Sveavägen 10',
        status: RequestStatus.accepted,
      );
      provider.requests.add(req);

      expect(provider.hasUnreadChat('req-1'), isFalse);
      expect(provider.getUnreadChatCount('req-1'), 0);
      expect(provider.totalUnreadChatCount, 0);
      expect(provider.lastIncomingChatMessage, isNull);

      // Incoming message from Helper
      final msg1 = ChatMessage(
        id: 'msg-1',
        requestId: 'req-1',
        senderId: 'helper-99',
        senderRole: 'helper',
        senderName: 'Erik Helper',
        text: 'Jag är på väg!',
        createdAt: now,
      );

      provider.handleIncomingChatMessage(msg1);

      expect(provider.hasUnreadChat('req-1'), isTrue);
      expect(provider.getUnreadChatCount('req-1'), 1);
      expect(provider.totalUnreadChatCount, 1);
      expect(provider.lastIncomingChatMessage, equals(msg1));

      // Second incoming message
      final msg2 = ChatMessage(
        id: 'msg-2',
        requestId: 'req-1',
        senderId: 'helper-99',
        senderRole: 'helper',
        senderName: 'Erik Helper',
        text: 'Framme vid porten!',
        createdAt: now.add(const Duration(minutes: 5)),
      );

      provider.handleIncomingChatMessage(msg2);

      expect(provider.getUnreadChatCount('req-1'), 2);
      expect(provider.totalUnreadChatCount, 2);
      expect(provider.lastIncomingChatMessage, equals(msg2));

      // Clear last incoming message (e.g. banner auto-dismissed)
      provider.clearLastIncomingChatMessage();
      expect(provider.lastIncomingChatMessage, isNull);
      // Unread count stays active until explicitly read
      expect(provider.hasUnreadChat('req-1'), isTrue);
      expect(provider.getUnreadChatCount('req-1'), 2);

      // Mark chat as read
      provider.markChatAsRead('req-1');
      expect(provider.hasUnreadChat('req-1'), isFalse);
      expect(provider.getUnreadChatCount('req-1'), 0);
      expect(provider.totalUnreadChatCount, 0);
    });

    test('PantaProvider ignores outgoing messages for unread notifications', () async {
      final provider = PantaProvider();
      await provider.restoreSession();

      // Current user is recycler (user role)
      final outgoingMsg = ChatMessage(
        id: 'msg-out',
        requestId: 'req-1',
        senderId: provider.currentUserId ?? '',
        senderRole: 'user',
        senderName: 'Anna Recycler',
        text: 'Portkoden är 1234',
        createdAt: DateTime.now(),
      );

      provider.handleIncomingChatMessage(outgoingMsg);

      expect(provider.hasUnreadChat('req-1'), isFalse);
      expect(provider.getUnreadChatCount('req-1'), 0);
      expect(provider.lastIncomingChatMessage, isNull);
    });

    testWidgets('ChatNotificationListener displays animated banner when new message arrives', (tester) async {
      final provider = PantaProvider();
      await provider.restoreSession();

      final req = RecyclingRequest(
        id: 'req-banner-1',
        title: 'Glass bottles',
        scheduledFrom: DateTime.now(),
        scheduledTo: DateTime.now().add(const Duration(hours: 1)),
        location: 'Storgatan 4',
        status: RequestStatus.accepted,
      );
      provider.requests.add(req);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('sv')],
          home: ChangeNotifierProvider<PantaProvider>.value(
            value: provider,
            child: const ChatNotificationListener(
              child: Scaffold(
                body: Center(child: Text('Dashboard Content')),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially no banner
      expect(find.text('NEW'), findsNothing);
      expect(find.text('Jag är vid dörren!'), findsNothing);

      // Send incoming message
      final incoming = ChatMessage(
        id: 'msg-banner-1',
        requestId: 'req-banner-1',
        senderId: 'helper-42',
        senderRole: 'helper',
        senderName: 'Erik Helper',
        text: 'Jag är vid dörren!',
        createdAt: DateTime.now(),
      );

      provider.handleIncomingChatMessage(incoming);
      await tester.pump(); // schedules post frame callback
      await tester.pump(); // triggers _triggerNotification setState
      await tester.pumpAndSettle(); // completes entry animation

      // Banner should now be visible
      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('Erik Helper'), findsOneWidget);
      expect(find.text('Jag är vid dörren!'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);

      // Tap Dismiss close icon
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle(); // completes reverse animation and removal

      expect(find.text('Jag är vid dörren!'), findsNothing);
    });

    testWidgets('UserRequestCard displays prominent unread badge and preview bubble', (tester) async {
      final provider = PantaProvider();
      await provider.restoreSession();

      final req = RecyclingRequest(
        id: 'req-card-1',
        title: 'Pantburkar',
        scheduledFrom: DateTime.now(),
        scheduledTo: DateTime.now().add(const Duration(hours: 1)),
        location: 'Kungsgatan 1',
        status: RequestStatus.accepted,
      );
      provider.requests.add(req);

      Widget buildTestWidget() => MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('sv')],
            home: ChangeNotifierProvider<PantaProvider>.value(
              value: provider,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: UserRequestCard(request: req),
                ),
              ),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initially no unread badge
      expect(find.text('Chat with Helper'), findsOneWidget);
      expect(find.textContaining('NEW'), findsNothing);

      // Helper sends a message
      final msg = ChatMessage(
        id: 'msg-preview-1',
        requestId: 'req-card-1',
        senderId: 'helper-55',
        senderRole: 'helper',
        senderName: 'Erik Helper',
        text: 'Jag har tagit hissen upp',
        createdAt: DateTime.now(),
      );

      provider.handleIncomingChatMessage(msg);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now prominent unread badge and bubble appear
      expect(find.text('Chat with Helper (1 NEW)'), findsOneWidget);
      expect(find.text('Jag har tagit hissen upp'), findsOneWidget);
      expect(find.text('1 NEW'), findsOneWidget);

      // Mark read
      provider.markChatAsRead('req-card-1');
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Returns to standard button with message count
      expect(find.text('Chat with Helper (1)'), findsOneWidget);
      expect(find.textContaining('NEW'), findsNothing);
    });

    testWidgets('HelperJobCard displays prominent unread badge and preview bubble', (tester) async {
      final provider = PantaProvider();
      await provider.restoreSession();
      await provider.loginDirect(role: 'helper', username: 'Erik Helper', seedIfEmpty: false);

      final job = RecyclingRequest(
        id: 'req-job-1',
        title: 'Pantburkar för upphämtning',
        scheduledFrom: DateTime.now(),
        scheduledTo: DateTime.now().add(const Duration(hours: 1)),
        location: 'Vasagatan 10',
        status: RequestStatus.accepted,
        helperId: provider.currentUserId,
      );
      provider.requests.add(job);

      Widget buildTestWidget() => MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('sv')],
            home: ChangeNotifierProvider<PantaProvider>.value(
              value: provider,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: HelperJobCard(
                    job: job,
                    isAcceptable: false,
                    isCompleted: false,
                  ),
                ),
              ),
            ),
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initially standard chat button
      expect(find.text('Chat'), findsOneWidget);
      expect(find.textContaining('NEW'), findsNothing);

      // Recycler sends a message to Helper
      final msg = ChatMessage(
        id: 'msg-job-1',
        requestId: 'req-job-1',
        senderId: 'recycler-88',
        senderRole: 'user',
        senderName: 'Anna Recycler',
        text: 'Påsarna står direkt till vänster',
        createdAt: DateTime.now(),
      );

      provider.handleIncomingChatMessage(msg);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Unread badge and preview bubble visible
      expect(find.text('Chat (1 NEW)'), findsOneWidget);
      expect(find.text('Påsarna står direkt till vänster'), findsOneWidget);
      expect(find.text('1 NEW'), findsOneWidget);

      // Mark read
      provider.markChatAsRead('req-job-1');
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Chat (1)'), findsOneWidget);
      expect(find.textContaining('NEW'), findsNothing);
    });
  });
}
