import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:panta/core/localization/app_localizations.dart';
import 'package:panta/features/chat/chat_bottom_sheet.dart';
import 'package:panta/models/chat_message.dart';
import 'package:panta/models/request_model.dart';
import 'package:panta/providers/panta_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp(
      {required Widget child, required PantaProvider provider}) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('sv')],
      home: ChangeNotifierProvider<PantaProvider>.value(
        value: provider,
        child: Scaffold(body: child),
      ),
    );
  }

  group('ChatBottomSheet autoscroll', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('autoscrolls to bottom when opened with existing messages',
        (tester) async {
      final provider = PantaProvider();
      await provider.restoreSession();

      final initialMessages = List.generate(
        25,
        (i) => ChatMessage(
          id: 'msg-$i',
          requestId: 'req-chat-test',
          senderId: i.isEven ? 'user-1' : 'helper-1',
          senderRole: i.isEven ? 'user' : 'helper',
          senderName: i.isEven ? 'User' : 'Helper',
          text: 'Message $i: detail text for chat scrolling test line.',
          createdAt: DateTime.now().add(Duration(minutes: i)),
        ),
      );

      final req = RecyclingRequest(
        id: 'req-chat-test',
        title: 'Test Request',
        scheduledFrom: DateTime.now(),
        scheduledTo: DateTime.now().add(const Duration(hours: 1)),
        location: 'Test Location',
        messages: initialMessages,
      );

      provider.requests.add(req);

      await tester.pumpWidget(buildTestApp(
        child: ChatBottomSheet(request: req, isHelper: false),
        provider: provider,
      ));

      await tester.pumpAndSettle();

      // The latest message (index 24) must be visible on screen
      expect(find.textContaining('Message 24:'), findsOneWidget);

      // The first messages (index 0, 1) should have been scrolled out of view
      expect(find.textContaining('Message 0:'), findsNothing);
    });

    testWidgets('smoothly autoscrolls down when a new incoming message arrives',
        (tester) async {
      final provider = PantaProvider();
      await provider.restoreSession();

      final initialMessages = List.generate(
        20,
        (i) => ChatMessage(
          id: 'msg-$i',
          requestId: 'req-chat-test-2',
          senderId: i.isEven ? 'user-1' : 'helper-1',
          senderRole: i.isEven ? 'user' : 'helper',
          senderName: i.isEven ? 'User' : 'Helper',
          text: 'Existing message $i in thread',
          createdAt: DateTime.now().add(Duration(minutes: i)),
        ),
      );

      final req = RecyclingRequest(
        id: 'req-chat-test-2',
        title: 'Incoming Message Test',
        scheduledFrom: DateTime.now(),
        scheduledTo: DateTime.now().add(const Duration(hours: 1)),
        location: 'Test Location',
        messages: initialMessages,
      );

      provider.requests.add(req);

      await tester.pumpWidget(buildTestApp(
        child: ChatBottomSheet(request: req, isHelper: false),
        provider: provider,
      ));

      await tester.pumpAndSettle();

      expect(find.textContaining('Existing message 19'), findsOneWidget);
      expect(find.textContaining('BRAND NEW ARRIVING MESSAGE'), findsNothing);

      // Helper sends a new message while the sheet is open
      final incoming = ChatMessage(
        id: 'msg-incoming-new',
        requestId: 'req-chat-test-2',
        senderId: 'helper-1',
        senderRole: 'helper',
        senderName: 'Helper',
        text: 'BRAND NEW ARRIVING MESSAGE',
        createdAt: DateTime.now().add(const Duration(minutes: 30)),
      );

      provider.handleIncomingChatMessage(incoming);
      await tester.pumpAndSettle();

      // New message should now be in view
      expect(find.textContaining('BRAND NEW ARRIVING MESSAGE'), findsOneWidget);
    });

    testWidgets('autoscrolls to bottom when messages load into empty chat',
        (tester) async {
      final provider = PantaProvider();
      await provider.restoreSession();

      final req = RecyclingRequest(
        id: 'req-chat-test-3',
        title: 'Async Loaded Test',
        scheduledFrom: DateTime.now(),
        scheduledTo: DateTime.now().add(const Duration(hours: 1)),
        location: 'Test Location',
        messages: const [],
      );

      provider.requests.add(req);

      await tester.pumpWidget(buildTestApp(
        child: ChatBottomSheet(request: req, isHelper: false),
        provider: provider,
      ));

      await tester.pumpAndSettle();

      // Initially empty
      expect(find.text('No messages yet'), findsOneWidget);

      // Multiple messages arrive
      for (int i = 0; i < 20; i++) {
        provider.handleIncomingChatMessage(ChatMessage(
          id: 'msg-async-$i',
          requestId: 'req-chat-test-3',
          senderId: 'helper-1',
          senderRole: 'helper',
          senderName: 'Helper',
          text: 'Async loaded message $i',
          createdAt: DateTime.now().add(Duration(minutes: i)),
        ));
      }

      await tester.pumpAndSettle();

      // Empty state should be gone, latest message visible
      expect(find.text('No messages yet'), findsNothing);
      expect(find.textContaining('Async loaded message 19'), findsOneWidget);
      expect(find.textContaining('Async loaded message 0'), findsNothing);
    });

    testWidgets(
        'autoscrolls to keep latest message visible when keyboard appears',
        (tester) async {
      final provider = PantaProvider();
      await provider.restoreSession();

      final initialMessages = List.generate(
        20,
        (i) => ChatMessage(
          id: 'msg-$i',
          requestId: 'req-chat-kb',
          senderId: i.isEven ? 'user-1' : 'helper-1',
          senderRole: i.isEven ? 'user' : 'helper',
          senderName: i.isEven ? 'User' : 'Helper',
          text: 'Message $i before keyboard opens',
          createdAt: DateTime.now().add(Duration(minutes: i)),
        ),
      );

      final req = RecyclingRequest(
        id: 'req-chat-kb',
        title: 'Keyboard Test',
        scheduledFrom: DateTime.now(),
        scheduledTo: DateTime.now().add(const Duration(hours: 1)),
        location: 'Test Location',
        messages: initialMessages,
      );

      provider.requests.add(req);

      await tester.pumpWidget(buildTestApp(
        child: ChatBottomSheet(request: req, isHelper: false),
        provider: provider,
      ));

      await tester.pumpAndSettle();
      expect(find.textContaining('Message 19 before keyboard opens'),
          findsOneWidget);

      // Simulate soft keyboard opening
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('Message 19 before keyboard opens'),
          findsOneWidget);

      // Reset viewInsets
      tester.view.resetViewInsets();
    });
  });
}
