import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/time_entry.dart';
import '../../services/time_tracking_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

const List<_ClockWorkSiteOption> _clockWorkSiteOptions = [
  _ClockWorkSiteOption(
    value: 'WORKSHOP',
    title: 'Taller',
    subtitle: 'Jornada en taller, base o instalaciones propias.',
    icon: Icons.home_repair_service_rounded,
    accent: NavalgoColors.tide,
  ),
  _ClockWorkSiteOption(
    value: 'TRAVEL',
    title: 'Viaje',
    subtitle: 'Jornada en desplazamiento o servicio fuera del taller.',
    icon: Icons.route_rounded,
    accent: NavalgoColors.harbor,
  ),
];

class FichajeScreen extends StatefulWidget {
  const FichajeScreen({super.key});

  @override
  State<FichajeScreen> createState() => _FichajeScreenState();
}

class _FichajeScreenState extends State<FichajeScreen> {
  bool _isLoading = true;
  String? _error;
  bool _isPunchedIn = false;
  List<TimeEntry> _entries = <TimeEntry>[];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final session = context.read<SessionViewModel>();
    final token = session.token;
    final workerId = session.user?.id;

    if (token == null || workerId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Sesión no válida';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final timeTrackingService = context.read<TimeTrackingService>();
      final entries = await timeTrackingService.getByWorker(
        token,
        workerId: workerId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _isPunchedIn = entries.any((e) => e.clockOut == null);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleClock() async {
    final session = context.read<SessionViewModel>();
    final token = session.token;
    final workerId = session.user?.id;
    final messenger = ScaffoldMessenger.of(context);
    final timeTrackingService = context.read<TimeTrackingService>();

    if (token == null || workerId == null) {
      return;
    }

    try {
      if (_isPunchedIn) {
        await timeTrackingService.clockOut(token, workerId: workerId);
      } else {
        final workSite = await _selectWorkSite();
        if (!mounted || workSite == null) {
          return;
        }
        await timeTrackingService.clockIn(
          token,
          workerId: workerId,
          workSite: workSite,
        );
      }
      await _loadEntries();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('No se pudo fichar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error!)),
        floatingActionButton: FloatingActionButton(
          onPressed: _loadEntries,
          child: const Icon(Icons.refresh),
        ),
      );
    }

    final todayEntries = _entries.where(_isToday).toList();
    final totalToday = todayEntries.fold<Duration>(
      Duration.zero,
      (acc, item) => acc + _durationForEntry(item),
    );
    final activeEntry = _entries.cast<TimeEntry?>().firstWhere(
      (item) => item?.clockOut == null,
      orElse: () => null,
    );

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const NavalgoPageIntro(
            eyebrow: 'CONTROL HORARIO',
            title: 'Registra tu jornada y el tipo de servicio de forma clara.',
            subtitle:
                'Indica si trabajas en taller o en viaje, revisa el tiempo acumulado y consulta los últimos movimientos del día.',
          ),
          const SizedBox(height: 18),
          NavalgoPanel(
            child: Column(
              children: [
                Icon(
                  _isPunchedIn ? Icons.timer : Icons.timer_off,
                  size: 92,
                  color: _isPunchedIn
                      ? NavalgoColors.kelp
                      : NavalgoColors.storm,
                ),
                const SizedBox(height: 20),
                Text(
                  _isPunchedIn
                      ? 'Estado: Trabajando'
                      : 'Estado: Fuera de turno',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Total hoy: ${_formatDuration(totalToday)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (activeEntry != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ubicación actual: ${_workSiteLabel(activeEntry.workSite)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _isPunchedIn
                          ? NavalgoColors.coral
                          : NavalgoColors.kelp,
                    ),
                    onPressed: _toggleClock,
                    icon: Icon(_isPunchedIn ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      _isPunchedIn ? 'Finalizar Turno' : 'Iniciar Turno',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const NavalgoSectionHeader(
            title: 'Últimos registros',
            subtitle: 'Entradas y salidas recientes de la jornada.',
          ),
          const SizedBox(height: 12),
          ..._entries.take(6).map((item) {
            final duration = _durationForEntry(item);
            final active = item.clockOut == null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NavalgoPanel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: (active ? NavalgoColors.kelp : NavalgoColors.coral)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      active ? Icons.login : Icons.logout,
                      color: active ? NavalgoColors.kelp : NavalgoColors.coral,
                    ),
                  ),
                  title: Text(_fmtDate(item.clockIn)),
                  subtitle: Text(
                    '${_workSiteLabel(item.workSite)} • Entrada: ${_fmtHour(item.clockIn)} - Salida: ${item.clockOut == null ? '--:--' : _fmtHour(item.clockOut!)}',
                  ),
                  trailing: Text(
                    _formatDuration(duration),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  bool _isToday(TimeEntry entry) {
    final now = DateTime.now();
    final inLocal = entry.clockIn.toLocal();
    return inLocal.year == now.year &&
        inLocal.month == now.month &&
        inLocal.day == now.day;
  }

  Duration _durationForEntry(TimeEntry entry) {
    final out = entry.clockOut?.toLocal() ?? DateTime.now();
    return out.difference(entry.clockIn.toLocal());
  }

  Future<String?> _selectWorkSite() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: NavalgoColors.heroGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Dónde comienza la jornada?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Selecciona si el fichaje de hoy corresponde a taller o a viaje.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ..._clockWorkSiteOptions.map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildWorkSiteAction(
                      context: sheetContext,
                      option: option,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkSiteAction({
    required BuildContext context,
    required _ClockWorkSiteOption option,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).pop(option.value),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: option.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: option.accent.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: option.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(option.icon, color: option.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: option.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _workSiteLabel(String workSite) {
    switch (workSite) {
      case 'TRAVEL':
        return 'Viaje';
      default:
        return 'Taller';
    }
  }

  String _fmtDate(DateTime d) {
    final local = d.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  String _fmtHour(DateTime d) {
    final local = d.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return '0h 00m';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m';
  }
}

class _ClockWorkSiteOption {
  const _ClockWorkSiteOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
}
