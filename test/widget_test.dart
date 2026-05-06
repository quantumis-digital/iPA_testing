import 'package:flutter_test/flutter_test.dart';

import 'package:homeinventory/main.dart';

void main() {
  testWidgets('Home screen shows app title and main actions', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('Home Organizer'), findsWidgets);
    expect(find.text('Find My Things'), findsOneWidget);
  });
}
