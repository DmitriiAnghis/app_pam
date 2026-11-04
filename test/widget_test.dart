import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:app_pam/data/auth_api.dart';
import 'package:app_pam/data/mock_repositories.dart';
import 'package:app_pam/main.dart';
import 'package:app_pam/models/locations_model.dart';
import 'package:app_pam/models/movements_model.dart';
import 'package:app_pam/models/products_model.dart';
import 'package:app_pam/models/profile_model.dart';
import 'package:app_pam/router.dart';

import 'fakes.dart';

Widget _app(MockBackend backend) => MultiProvider(
      providers: [
        Provider<AuthApi>(create: (_) => FakeAuthApi()),
        Provider<MockBackend>.value(value: backend),
        ChangeNotifierProvider(
            create: (_) => ProductsModel(MockProductRepository(backend))..load()),
        ChangeNotifierProvider(
            create: (_) =>
                LocationsModel(MockLocationRepository(backend))..load()),
        ChangeNotifierProvider(
            create: (_) =>
                MovementsModel(MockMovementRepository(backend))..load()),
        ChangeNotifierProvider(
            create: (_) => ProfileModel(MockUserRepository(backend))..load()),
      ],
      child: const MyApp(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  router = GoRouter(initialLocation: '/login', routes: appRoutes);
  setUp(() => router.go('/login'));

  testWidgets('Вход: ошибки валидации, неверный пароль, затем каталог',
      (tester) async {
    await tester.pumpWidget(_app(MockBackend()));
    expect(find.text('StockPilot'), findsOneWidget);

    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Введите e-mail'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'ana@test.md');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong12');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Неверный email или пароль'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'parola123');
    await tester.tap(find.text('Войти'));
    await tester.pump();
    expect(find.text('Каталог товаров'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Найдено товаров: 9'), findsOneWidget);
  });

  testWidgets('Авария mock-а показывает экран ошибки с «Повторить»',
      (tester) async {
    final backend = MockBackend()..simulateError = true;

    await tester.pumpWidget(_app(backend));
    await tester.enterText(find.byType(TextFormField).at(0), 'ana@test.md');
    await tester.enterText(find.byType(TextFormField).at(1), 'parola123');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Повторить'), findsOneWidget);

    backend.simulateError = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Найдено товаров: 9'), findsOneWidget);
  });
}
