import 'package:flutter/material.dart';
import 'package:navalgo/services/auth_service.dart';
import 'package:navalgo/services/fleet_service.dart';
import 'package:navalgo/services/leave_service.dart';
import 'package:navalgo/services/time_tracking_service.dart';
import 'package:navalgo/services/worker_service.dart';
import 'package:navalgo/services/work_order_service.dart';
import 'package:navalgo/viewmodels/fleet_view_model.dart';
import 'package:navalgo/viewmodels/login_view_model.dart';
import 'package:navalgo/viewmodels/session_view_model.dart';
import 'package:navalgo/viewmodels/work_orders_view_model.dart';
import 'package:navalgo/viewmodels/workers_view_model.dart';
import 'package:provider/provider.dart';
import 'screens/admin/admin_shell_screen.dart';
import 'screens/common/login_screen.dart';
import 'screens/worker/worker_shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionViewModel = SessionViewModel();
  await sessionViewModel.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionViewModel>.value(value: sessionViewModel),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<WorkerService>(create: (_) => WorkerService()),
        Provider<FleetService>(create: (_) => FleetService()),
        Provider<LeaveService>(create: (_) => LeaveService()),
        Provider<TimeTrackingService>(create: (_) => TimeTrackingService()),
        Provider<WorkOrderService>(create: (_) => WorkOrderService()),
        ChangeNotifierProvider(
          create: (context) =>
              LoginViewModel(
                authService: context.read<AuthService>(),
                session: context.read<SessionViewModel>(),
              ),
        ),
        ChangeNotifierProvider(
          create: (context) => WorkersViewModel(
            workerService: context.read<WorkerService>(),
            session: context.read<SessionViewModel>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => FleetViewModel(
            fleetService: context.read<FleetService>(),
            session: context.read<SessionViewModel>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => WorkOrdersViewModel(
            workOrderService: context.read<WorkOrderService>(),
            session: context.read<SessionViewModel>(),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NavalGO',
      debugShowCheckedModeBanner: false, // Oculta la etiqueta roja de "DEBUG"
      theme: ThemeData(
        useMaterial3: true, // Activa el diseño moderno de Android/Flutter
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue.shade900, // Azul marino de base
        ),
        cardTheme: CardThemeData(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0), // Bordes más suaves
          ),
          clipBehavior: Clip.antiAlias, // Evita que el contenido se salga de los bordes
        ),
      ),
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends StatelessWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();

    if (!session.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!session.isAuthenticated || session.user == null) {
      return const LoginScreen();
    }

    return session.user!.role == 'ADMIN'
        ? const AdminShellScreen()
        : const WorkerShellScreen();
  }
}
