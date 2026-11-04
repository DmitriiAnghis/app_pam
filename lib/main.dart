import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'data/auth_api.dart';
import 'data/mock_repositories.dart';
import 'data/token_store.dart';
import 'models/locations_model.dart';
import 'models/movements_model.dart';
import 'models/products_model.dart';
import 'models/profile_model.dart';
import 'router.dart';

String get apiBase {
  const fromEnv = String.fromEnvironment('API_BASE');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://localhost:8080';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tokens = TokenStore();
  final loggedIn = await tokens.read() != null;

  router = GoRouter(
      initialLocation: loggedIn ? '/products' : '/login', routes: appRoutes);

  final backend = MockBackend();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthApi>(create: (_) => AuthApi(apiBase, tokens)),

        Provider<MockBackend>.value(value: backend),
        ChangeNotifierProvider(
          create: (_) => ProductsModel(MockProductRepository(backend))..load(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              LocationsModel(MockLocationRepository(backend))..load(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              MovementsModel(MockMovementRepository(backend))..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileModel(MockUserRepository(backend))..load(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StockPilot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEF6C00),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w600),
        ),
        cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      ),
      routerConfig: router,
    );
  }
}
