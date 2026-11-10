import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streammax_app/main.dart';

void main() {
  testWidgets('StreamMax App loads test', (WidgetTester tester) async {
    await tester.pumpWidget(const StreamMaxApp());
    // Initial loading indicator is displayed while feed is loading
    expect(find.byType(StreamMaxApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
