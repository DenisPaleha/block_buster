import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:block_buster/main.dart';

void main() {
  testWidgets('HomeScreen basic load test', (WidgetTester tester) async {
    // Собираем приложение с нашим корневым экраном HomeScreen
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(),
    ));

    // Проверяем, что заголовок приложения отображается на экране
    expect(find.text('Block Buster'), findsOneWidget);

    // Проверяем наличие текста баланса
    expect(find.text('Баланс оборотов:'), findsOneWidget);
  });
}