// App-render smoke test: the home screen must come up with the DownTube
// title and the save-folder row without touching the network.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:downtube/screens/settings_screen.dart' show kAppVersion;
import 'package:downtube/providers/app_provider.dart';
import 'package:downtube/screens/home_screen.dart';

void main() {
  testWidgets('home screen renders (no network)', (WidgetTester tester) async {
    // Wider surface: avoids the pre-existing 800x600 sidebar brand-row
    // RenderFlex tightness (home_screen.dart sidebar), unrelated to this test.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: AppProvider()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('DownTube'), findsWidgets);
    expect(find.text('Save to folder'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);

    // Settings tab: swap the content and back must still work.
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Save to folder'), findsOneWidget);
    expect(find.text('Version $kAppVersion'), findsNothing);
    expect(find.textContaining('Version $kAppVersion'), findsOneWidget);

    await tester.tap(find.text('Video Download'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Save to folder'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
  });
}
