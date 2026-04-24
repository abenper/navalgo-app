import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:navalgo/app/app_globals.dart';
import 'package:navalgo/firebase_options.dart';
import 'package:navalgo/services/network/api_client.dart';
import 'package:navalgo/services/auth_service.dart';
import 'package:navalgo/services/fleet_service.dart';
import 'package:navalgo/services/leave_service.dart';
import 'package:navalgo/services/material_checklist_template_service.dart';
import 'package:navalgo/services/notification_service.dart';
import 'package:navalgo/services/push_notification_service.dart';
import 'package:navalgo/services/time_tracking_service.dart';
import 'package:navalgo/services/worker_service.dart';
import 'package:navalgo/services/work_order_material_service.dart';
import 'package:navalgo/services/work_order_media_service.dart';
import 'package:navalgo/services/work_order_service.dart';
import 'package:navalgo/services/worker_photo_service.dart';
import 'package:navalgo/theme/navalgo_theme.dart';
import 'package:navalgo/viewmodels/fleet_view_model.dart';
import 'package:navalgo/viewmodels/login_view_model.dart';
import 'package:navalgo/viewmodels/notifications_view_model.dart';
import 'package:navalgo/viewmodels/session_view_model.dart';
import 'package:navalgo/viewmodels/work_orders_view_model.dart';
import 'package:navalgo/viewmodels/workers_view_model.dart';
import 'package:provider/provider.dart';
import 'screens/common/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on UnsupportedError {
    // Firebase is not configured for every desktop target.
  }
  final sessionViewModel = SessionViewModel();
  await sessionViewModel.restoreSession();
  ApiClient.configureSessionExpiredHandler((message) async {
    await sessionViewModel.expireSession(message: message);

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionViewModel>.value(value: sessionViewModel),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<WorkerService>(create: (_) => WorkerService()),
        Provider<FleetService>(create: (_) => FleetService()),
        Provider<LeaveService>(create: (_) => LeaveService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
        Provider<PushNotificationService>(
          create: (_) => PushNotificationService(),
        ),
        Provider<TimeTrackingService>(create: (_) => TimeTrackingService()),
        Provider<MaterialChecklistTemplateService>(
          create: (_) => MaterialChecklistTemplateService(),
        ),
        Provider<WorkOrderService>(create: (_) => WorkOrderService()),
        Provider<WorkOrderMaterialService>(
          create: (_) => WorkOrderMaterialService(),
        ),
        Provider<WorkOrderMediaService>(create: (_) => WorkOrderMediaService()),
        Provider<WorkerPhotoService>(create: (_) => WorkerPhotoService()),
        ChangeNotifierProvider(
          create: (context) => LoginViewModel(
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
        ChangeNotifierProvider(
          create: (context) => NotificationsViewModel(
            notificationService: context.read<NotificationService>(),
            session: context.read<SessionViewModel>(),
          ),
        ),
      ],
      child: const _PushNotificationBootstrap(child: MyApp()),
    ),
  );
}

class _PushNotificationBootstrap extends StatefulWidget {
  const _PushNotificationBootstrap({required this.child});

  final Widget child;

  @override
  State<_PushNotificationBootstrap> createState() =>
      _PushNotificationBootstrapState();
}

class _PushNotificationBootstrapState extends State<_PushNotificationBootstrap> {
  String? _lastAuthToken;

  @override
  void dispose() {
    context.read<PushNotificationService>().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentAuthToken = context.select<SessionViewModel, String?>(
      (session) => session.token,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || currentAuthToken == _lastAuthToken) {
        return;
      }

      final previousAuthToken = _lastAuthToken;
      _lastAuthToken = currentAuthToken;

      context.read<PushNotificationService>().syncSession(
        previousAuthToken: previousAuthToken,
        currentAuthToken: currentAuthToken,
        notificationApi: context.read<NotificationService>(),
        refreshNotifications: context.read<NotificationsViewModel>().refresh,
      );
    });

    return widget.child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NavalGO',
      debugShowCheckedModeBanner: false, // Oculta la etiqueta roja de "DEBUG"
      navigatorKey: appNavigatorKey,
      theme: buildNavalgoTheme(),
      locale: const Locale('es'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es')],
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Always show LoginScreen — it handles routing for both
    // remember-me (auto-navigate in initState) and normal login.
    return const LoginScreen();
  }
}
