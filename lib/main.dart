import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'data/api_client.dart';
import 'data/auth_api.dart';
import 'data/http_repositories.dart';
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

  final api = ApiClient(apiBase, tokens,
      onUnauthorized: () => router.go('/login'));

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthApi>(create: (_) => AuthApi(apiBase, tokens)),
        ChangeNotifierProvider(
          create: (_) => ProductsModel(HttpProductRepository(api))..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => LocationsModel(HttpLocationRepository(api))..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => MovementsModel(HttpMovementRepository(api))..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileModel(HttpUserRepository(api))..load(),
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
