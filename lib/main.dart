import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/timer_service.dart';
import 'services/set_controller.dart';
import 'services/device_status_service.dart';
import 'services/auth_service.dart';
import 'services/led_sign_service.dart';
import 'services/bluetooth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: kBackgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const SetStopApp());
}

class SetStopApp extends StatelessWidget {
  const SetStopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => TimerService()),
        ChangeNotifierProvider(create: (_) => DeviceStatusService()),
        ChangeNotifierProvider(create: (_) => LedSignService()),
        ChangeNotifierProvider(create: (_) => BluetoothSignService()),
        ChangeNotifierProxyProvider<TimerService, SetController>(
          create: (ctx) => SetController(
            timerService: ctx.read<TimerService>(),
          ),
          update: (ctx, timer, prev) =>
              prev ?? SetController(timerService: timer),
        ),
      ],
      child: MaterialApp(
        title: 'SET-STOP',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.dark(
            surface: kSurfaceColor,
            primary: kGreenActive,
            secondary: kRedActive,
          ),
          scaffoldBackgroundColor: kBackgroundColor,
          useMaterial3: true,
          dividerColor: kDividerColor,
        ),
        home: const _AppEntry(),
      ),
    );
  }
}

// ─── Entry point: Splash → decide Login o Main ───────────────────────────────
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Mostrar splash mínimo 2.2 segundos
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final auth = context.read<AuthService>();
    if (auth.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}
