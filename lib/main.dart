import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:navalgo/app/app_globals.dart';
import 'package:navalgo/firebase_options.dart';
import 'package:navalgo/services/network/api_client.dart';
import 'package:navalgo/services/auth_service.dart';
import 'package:navalgo/services/app_update_service.dart';
import 'package:navalgo/services/budget_service.dart';
import 'package:navalgo/services/fleet_service.dart';
import 'package:navalgo/services/leave_service.dart';
import 'package:navalgo/services/material_checklist_template_service.dart';
import 'package:navalgo/services/notification_service.dart';
import 'package:navalgo/services/push_debug_service.dart';
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
import 'screens/common/complete_registration_screen.dart';
import 'screens/common/create_account_screen.dart';
import 'screens/common/login_screen.dart';
import 'screens/common/privacy_policy_screen.dart';
import 'screens/common/reset_password_screen.dart';
import 'screens/common/verify_email_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();

  // On web, Firebase init can hang silently when the Service Worker is
  // blocked (e.g. site served over HTTP). Don't await it on the critical
  // path so login renders immediately even if FCM is unavailable.
  if (kIsWeb) {
    unawaited(_initFirebaseSafely());
  } else {
    await _initFirebaseSafely();
  }

  final sessionViewModel = SessionViewModel(authService: authService);
  try {
    await sessionViewModel.restoreSession();
  } catch (error, stackTrace) {
    debugPrint('Session restore failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
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
  ApiClient.configureAccessTokenRefreshHandler(() async {
    final refreshed = await sessionViewModel.refreshSession();
    return refreshed ? sessionViewModel.token : null;
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionViewModel>.value(value: sessionViewModel),
        Provider<AuthService>.value(value: authService),
        Provider<AppUpdateService>(create: (_) => AppUpdateService()),
        Provider<BudgetService>(create: (_) => BudgetService()),
        Provider<WorkerService>(create: (_) => WorkerService()),
        Provider<FleetService>(create: (_) => FleetService()),
        Provider<LeaveService>(create: (_) => LeaveService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
        Provider<PushDebugService>(create: (_) => PushDebugService()),
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

Future<void> _initFirebaseSafely() async {
  try {
    if (Firebase.apps.isNotEmpty) {
      return;
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        throw TimeoutException('Firebase init exceeded 3s');
      },
    );
  } on UnsupportedError {
    // Firebase is not configured for every desktop target.
  } on TimeoutException catch (error) {
    debugPrint('Firebase init timeout: $error');
  } catch (error, stackTrace) {
    debugPrint('Firebase init failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class _PushNotificationBootstrap extends StatefulWidget {
  const _PushNotificationBootstrap({required this.child});

  final Widget child;

  @override
  State<_PushNotificationBootstrap> createState() =>
      _PushNotificationBootstrapState();
}

class _PushNotificationBootstrapState
    extends State<_PushNotificationBootstrap> {
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
      home: const _StartupPermissionsGate(
        child: _AndroidUpdateGate(child: _RootScreen()),
      ),
    );
  }
}

class _StartupPermissionsGate extends StatefulWidget {
  const _StartupPermissionsGate({required this.child});

  final Widget child;

  @override
  State<_StartupPermissionsGate> createState() =>
      _StartupPermissionsGateState();
}

class _StartupPermissionsGateState extends State<_StartupPermissionsGate> {
  Future<void>? _startupRequest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startupRequest = _requestStartupPermissions();
      });
    });
  }

  Future<void> _requestStartupPermissions() async {
    if (kIsWeb) {
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    await Permission.notification.request();
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.location.request();
    await Permission.locationWhenInUse.request();
  }

  @override
  Widget build(BuildContext context) {
    final request = _startupRequest;
    if (request == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FutureBuilder<void>(
      future: request,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return widget.child;
      },
    );
  }
}

class _AndroidUpdateGate extends StatefulWidget {
  const _AndroidUpdateGate({required this.child});

  final Widget child;

  @override
  State<_AndroidUpdateGate> createState() => _AndroidUpdateGateState();
}

class _AndroidUpdateGateState extends State<_AndroidUpdateGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _checked) {
        return;
      }
      _checked = true;
      unawaited(_checkForAndroidUpdate());
    });
  }

  Future<void> _checkForAndroidUpdate() async {
    try {
      final service = context.read<AppUpdateService>();
      final update = await service.checkAndroidUpdate();
      if (!mounted || update == null) {
        return;
      }

      final shouldDownload = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Nueva version disponible'),
            content: Text(
              update.releaseNotes == null || update.releaseNotes!.isEmpty
                  ? 'Hay una nueva version de NavalGO disponible. Deseas descargarla?'
                  : 'Hay una nueva version de NavalGO disponible.\n\n${update.releaseNotes}\n\nDeseas descargarla?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Ahora no'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Descargar'),
              ),
            ],
          );
        },
      );

      if (!mounted || shouldDownload != true) {
        return;
      }

      await service.downloadAndroidApk(update);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Descargando APK en la carpeta Descargas.'),
        ),
      );
    } catch (error) {
      debugPrint('Android update check failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _RootScreen extends StatelessWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context) {
    if (isCompleteRegistrationEntryUri(Uri.base)) {
      return CompleteRegistrationScreen(
        token: Uri.base.queryParameters['token'] ?? '',
      );
    }

    if (isPrivacyPolicyEntryUri(Uri.base)) {
      return const PrivacyPolicyScreen(isPublicEntry: true);
    }

    if (isCreateAccountEntryUri(Uri.base)) {
      return CreateAccountScreen(
        prefilledName: Uri.base.queryParameters['name'],
        prefilledEmail: Uri.base.queryParameters['email'],
      );
    }

    if (isVerifyEmailEntryUri(Uri.base)) {
      return VerifyEmailScreen(token: Uri.base.queryParameters['token'] ?? '');
    }

    if (isResetPasswordEntryUri(Uri.base)) {
      return ResetPasswordScreen(
        token: Uri.base.queryParameters['token'] ?? '',
      );
    }

    final session = context.watch<SessionViewModel>();

    if (!session.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Always show LoginScreen — it handles routing for both
    // remember-me (auto-navigate in initState) and normal login.
    return const LoginScreen();
  }
}
