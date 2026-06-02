import 'dart:convert';
import 'dart:io'; // Para HttpOverrides
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/api_constants.dart';
import 'core/api_service.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/navigation/main_nav_screen.dart';

// --- CLASE PARA PERMITIR HTTPS LOCAL EN DESARROLLO ---
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Aplicamos los overrides para que acepte tu API de Parallels por HTTPS
  HttpOverrides.global = MyHttpOverrides();
  
  await initializeDateFormatting('es', null);
  runApp(const RentaFestApp());
}

// El resto de RentaFestApp se mantiene igual...
class AppStateProvider extends InheritedWidget {
  final AppPlan plan;
  final ThemeMode themeMode;
  final bool isLoggedIn;
  final RentaFestAppState state;
  final String? empresa;
  final String? telefono;

  const AppStateProvider({
    super.key,
    required this.plan,
    required this.themeMode,
    required this.isLoggedIn,
    required this.state,
    this.empresa,
    this.telefono,
    required super.child,
  });

  static AppStateProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppStateProvider>()!;
  }

  @override
  bool updateShouldNotify(AppStateProvider oldWidget) {
    return plan != oldWidget.plan || themeMode != oldWidget.themeMode || isLoggedIn != oldWidget.isLoggedIn;
  }
}

class RentaFestApp extends StatefulWidget {
  const RentaFestApp({super.key});

  @override
  State<RentaFestApp> createState() => RentaFestAppState();

  static RentaFestAppState of(BuildContext context) {
    return AppStateProvider.of(context).state;
  }
}

class RentaFestAppState extends State<RentaFestApp> {
  bool _isLoggedIn = false;
  AppPlan _plan = AppPlan.free; 
  ThemeMode _themeMode = ThemeMode.system;

  String? _empresa;
  String? _telefono;

  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    initializeSession();
  }

  Future<void> initializeSession() async {
    final token = await ApiService.loadToken();

    if (token == null || token.isEmpty) {
      setState(() {
        _isInitializing = false;
        _isLoggedIn = false;
        _plan = AppPlan.free;
      });

      return;
    }

    try {
      final response = await ApiService.post(
        ApiConstants.refresh,
        {},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['ok'] == true) {
        await ApiService.setToken(data['token']);
        setPlanFromString(data['plan'] ?? 'free');

        setState(() {
          _isInitializing = false;
          _isLoggedIn = true;
        });
      } else {
        await ApiService.clearToken();

        setState(() {
          _isInitializing = false;
          _isLoggedIn = false;
          _plan = AppPlan.free;
        });
      }
    } catch (e) {
      await ApiService.clearToken();

      setState(() {
        _isInitializing = false;
        _isLoggedIn = false;
        _plan = AppPlan.free;
      });
    }
  }

  void login() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    setState(() {
      _isLoggedIn = false;
      _plan = AppPlan.free;
      _empresa = null;
      _telefono = null;
    });
  }
  
  void toggleTheme(ThemeMode mode) => setState(() => _themeMode = mode);
  void setPlanFromString(String plan) {
    final p = plan.toLowerCase();

    if (p == 'premium') {
      _plan = AppPlan.premium;
    } else if (p == 'basic') {
      _plan = AppPlan.basic;
    } else {
      _plan = AppPlan.free;
    }

    setState(() {});
  }
  void setPlan(AppPlan newPlan) => setState(() => _plan = newPlan);

  void setEmpresaData(String empresa, String telefono) {
    setState(() {
      _empresa = empresa;
      _telefono = telefono;
    });
  }

  AppPlan get plan => _plan;
  // iOS: todas las funciones disponibles sin restricción (App Store 3.1.1).
  bool get isPremium => Platform.isIOS || _plan == AppPlan.premium;
  bool get isAtLeastBasic => Platform.isIOS || _plan == AppPlan.basic || _plan == AppPlan.premium;
  ThemeMode get themeMode => _themeMode;
  String? get empresa => _empresa;
  String? get telefono => _telefono;

  @override
  Widget build(BuildContext context) {
    return AppStateProvider(
      plan: _plan,
      themeMode: _themeMode,
      isLoggedIn: _isLoggedIn,
      state: this,
      empresa: _empresa,
      telefono: _telefono,
      child: MaterialApp(
        key: ValueKey(_isLoggedIn),
        title: 'RentaFest',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _themeMode,
        home: _isInitializing
            ? const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        )
            : _isLoggedIn
            ? const MainNavigationScreen()
            : LoginScreen(onLogin: login),
      ),
    );
  }
}

enum AppPlan { free, basic, premium }
