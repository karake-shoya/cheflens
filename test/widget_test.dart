import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cheflens/main.dart';

void main() {
  testWidgets('ChefLens app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Cheflens - カメラ'), findsOneWidget);
    expect(find.text('写真を撮る'), findsOneWidget);
    expect(find.text('ギャラリーから選ぶ'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.byIcon(Icons.photo_library), findsOneWidget);
  });
}
