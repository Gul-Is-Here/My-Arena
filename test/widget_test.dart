import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import 'package:my_arena/main.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    await GetStorage.init();
    await tester.pumpWidget(const MyArenaApp());

    expect(find.text('MY ARENA'), findsOneWidget);

    // Bounded pumps (pumpAndSettle would hang on the splash spinner):
    // fire the 2s redirect timer, then let the route transition run.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
  });
}
