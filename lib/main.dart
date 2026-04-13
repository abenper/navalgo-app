import 'package:flutter/material.dart';
import 'package:navalgo/services/auth_service.dart';
import 'package:navalgo/services/fleet_service.dart';
import 'package:navalgo/services/worker_service.dart';
import 'package:navalgo/services/work_order_service.dart';
import 'package:navalgo/viewmodels/fleet_view_model.dart';
import 'package:navalgo/viewmodels/login_view_model.dart';
import 'package:navalgo/viewmodels/session_view_model.dart';
import 'package:navalgo/viewmodels/work_orders_view_model.dart';
import 'package:navalgo/viewmodels/workers_view_model.dart';
import 'package:provider/provider.dart';
import 'screens/common/login_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionViewModel>(
          create: (_) => SessionViewModel(),
        ),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<WorkerService>(create: (_) => WorkerService()),
        Provider<FleetService>(create: (_) => FleetService()),
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
      home: const LoginScreen(),
    );
  }
}
