import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/time_adjustment_request.dart';
import '../../models/time_entry.dart';
import '../../models/worker_profile.dart';
import '../../services/time_tracking_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../utils/app_toast.dart';
import '../../utils/media_url.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

class WorkerJornadaAdjustmentScreen extends StatefulWidget {
  const WorkerJornadaAdjustmentScreen({super.key, required this.worker});

  final WorkerProfile worker;

  @override
  State<WorkerJornadaAdjustmentScreen> createState() =>
      _WorkerJornadaAdjustmentScreenState();
}

class _WorkerJornadaAdjustmentScreenState
    extends State<WorkerJornadaAdjustmentScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _adjustmentBusy = false;
  String? _error;
  WorkerTimeTrackingInsight? _insight;
  List<TimeEntry> _entries = <TimeEntry>[];
  List<TimeAdjustmentRequest> _pendingAdjustmentRequests =
      <TimeAdjustmentRequest>[];

  bool get _isCommercial => widget.worker.role == 'COMERCIAL';

  bool get _isOperationalWorker => widget.worker.role == 'WORKER';

  String get _roleLabel => _isCommercial ? 'comercial' : 'trabajador';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Sesion no valida';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = context.read<TimeTrackingService>();
      final insight = await service.getWorkerInsight(token, workerId: widget.worker.id);
      final entries = await service.getByWorker(token, workerId: widget.worker.id);
      final adjustmentRequests = await service.getAdjustmentRequests(
        token,
        status: 'PENDING',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _insight = insight;
        _entries = entries;
        _pendingAdjustmentRequests = adjustmentRequests
            .where((request) => request.workerId == widget.worker.id)
            .toList();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editEntry(TimeEntry entry) async {
    final input = await showDialog<_EditTimeEntryInput>(
      context: context,
      builder: (context) => _EditTimeEntryDialog(entry: entry, role: widget.worker.role),
    );
    if (!mounted || input == null) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<TimeTrackingService>().updateTimeEntry(
        token,
        entryId: entry.id,
        clockIn: input.clockIn,
        clockOut: input.clockOut,
        plannedClockOut: input.plannedClockOut,
        workSite: input.workSite,
      );
      await _load();
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Jornada actualizada.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo actualizar la jornada: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _reviewAdjustmentRequest(
    TimeAdjustmentRequest request, {
    required bool approve,
  }) async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    final commentController = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            approve
                ? 'Aprobar ajuste de fichaje'
                : 'Rechazar ajuste de fichaje',
          ),
          content: TextField(
            controller: commentController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Comentario para el trabajador',
              hintText: 'Opcional',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, commentController.text.trim()),
              child: Text(approve ? 'Aprobar' : 'Rechazar'),
            ),
          ],
        );
      },
    );
    commentController.dispose();

    if (!mounted || comment == null) {
      return;
    }

    setState(() => _adjustmentBusy = true);
    try {
      await context.read<TimeTrackingService>().reviewAdjustmentRequest(
        token,
        requestId: request.id,
        status: approve ? 'APPROVED' : 'REJECTED',
        adminComment: comment.isEmpty ? null : comment,
      );
      await _load();
      if (!mounted) {
        return;
      }
      AppToast.success(
        context,
        approve
            ? 'Ajuste aprobado y aplicado.'
            : 'Solicitud rechazada correctamente.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo revisar la solicitud: $e');
    } finally {
      if (mounted) {
        setState(() => _adjustmentBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _insight == null) {
      return const Scaffold(
        body: NavalgoPageBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null && _insight == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ajuste de jornada')),
        body: NavalgoPageBackground(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: NavalgoPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 42,
                      color: NavalgoColors.coral,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No se pudo cargar la vista de ajuste.',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    NavalgoGradientButton(
                      label: 'Reintentar',
                      icon: Icons.refresh_rounded,
                      onPressed: _load,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final insight = _insight;
    if (insight == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isCommercial
              ? 'Ajuste de jornada comercial'
              : 'Ajuste de jornada técnica',
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: NavalgoPageBackground(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHero(context, insight),
              const SizedBox(height: 18),
              _buildQualityFactors(context, insight),
              const SizedBox(height: 18),
              _buildRoleSummary(context, insight),
              const SizedBox(height: 18),
              _buildPendingAdjustmentRequests(context),
              const SizedBox(height: 18),
              _buildEntries(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, WorkerTimeTrackingInsight insight) {
    final scoreColor = _scoreColor(insight.qualityScore);
    final token = context.read<SessionViewModel>().token;
    final photoUrl = resolveMediaUrl(widget.worker.photoUrl);

    return NavalgoPanel(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 860;
          final identity = _HeroIdentityCard(
            worker: widget.worker,
            photoUrl: photoUrl,
            token: token,
          );
          final score = _HeroScoreCard(
            score: insight.qualityScore,
            color: scoreColor,
            currentlyClockedIn: insight.currentlyClockedIn,
            isCommercial: _isCommercial,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: 16),
                    score,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 16),
                    SizedBox(width: 240, child: score),
                  ],
                ),
              const SizedBox(height: 16),
              _buildHeroPills(insight),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroPills(WorkerTimeTrackingInsight insight) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        NavalgoStatusChip(
          label: _isCommercial ? 'Rol comercial' : 'Rol técnico',
          color: _isCommercial ? NavalgoColors.harbor : NavalgoColors.tide,
        ),
        NavalgoStatusChip(
          label: insight.currentlyClockedIn ? 'Jornada abierta' : 'Jornada cerrada',
          color: insight.currentlyClockedIn
              ? NavalgoColors.kelp
              : NavalgoColors.storm,
        ),
        NavalgoStatusChip(
          label: _absenceComparisonLabel(insight.absenceVsAveragePercent),
          color: insight.absenceVsAveragePercent > 0
              ? NavalgoColors.coral
              : NavalgoColors.kelp,
        ),
      ],
    );
  }

  Widget _buildQualityFactors(BuildContext context, WorkerTimeTrackingInsight insight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NavalgoSectionHeader(
          title: _isCommercial ? 'Seguimiento horario' : 'Calidad operativa',
          subtitle: _isCommercial
              ? 'Constancia, presencia y ausencias del perfil comercial.'
              : 'Lectura rápida del rendimiento horario del perfil técnico.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 1180
                ? 4
                : constraints.maxWidth >= 760
                ? 2
                : 1;
            final childAspectRatio = crossAxisCount == 1 ? 2.2 : 1.55;

            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
              ),
              children: [
                NavalgoMetricCard(
                  label: 'Horas hoy',
                  value: _formatMinutes(insight.workedMinutesToday),
                  icon: const Icon(Icons.today_outlined),
                  accent: NavalgoColors.tide,
                  note: _isCommercial
                      ? 'Actividad registrada en la jornada actual.'
                      : 'Tiempo fichado en el día en curso.',
                ),
                NavalgoMetricCard(
                  label: 'Horas este mes',
                  value: _formatMinutes(insight.workedMinutesThisMonth),
                  icon: const Icon(Icons.calendar_view_month_rounded),
                  accent: NavalgoColors.harbor,
                  note: 'Acumulado del mes natural actual.',
                ),
                NavalgoMetricCard(
                  label: 'Horas este año',
                  value: _formatMinutes(insight.workedMinutesThisYear),
                  icon: const Icon(Icons.calendar_month_rounded),
                  accent: NavalgoColors.kelp,
                  note: 'Tiempo total registrado en el año.',
                ),
                NavalgoMetricCard(
                  label: 'Ausencias no vacacionales',
                  value: '${insight.approvedNonVacationAbsenceDaysThisYear}',
                  icon: const Icon(Icons.event_busy_outlined),
                  accent: NavalgoColors.coral,
                  note: _absenceComparisonLabel(insight.absenceVsAveragePercent),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        ...insight.qualityFactors.map(
          (factor) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NavalgoPanel(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _scoreColor(factor.score).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        factor.score.toStringAsFixed(0),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: _scoreColor(factor.score),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          factor.label,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(factor.detail),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSummary(BuildContext context, WorkerTimeTrackingInsight insight) {
    return _isOperationalWorker
        ? _buildOperationalSummary(context, insight)
        : _buildCommercialSummary(context, insight);
  }

  Widget _buildOperationalSummary(
    BuildContext context,
    WorkerTimeTrackingInsight insight,
  ) {
    final rows = insight.resolvedWorkOrderStats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NavalgoSectionHeader(
          title: 'Partes y horas',
          subtitle: 'Resumen visual de cierres, horas fichadas e imputación.',
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const NavalgoPanel(
            child: Text('Aún no hay histórico suficiente de partes cerrados.'),
          )
        else
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ResolvedPeriodCard(row: row),
            ),
          ),
      ],
    );
  }

  Widget _buildCommercialSummary(
    BuildContext context,
    WorkerTimeTrackingInsight insight,
  ) {
    final todayTarget = 8 * 60.0;
    final monthTarget = 160 * 60.0;
    final yearTarget = 1760 * 60.0;
    final absenceRatio =
        (insight.absenceVsAveragePercent.abs() / 100).clamp(0, 1).toDouble();

    return NavalgoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actividad comercial',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vista pensada para revisar presencia, constancia horaria y nivel de incidencias sin mezclar datos de partes.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _ActivityProgressRow(
            label: 'Ritmo diario',
            valueLabel: _formatMinutes(insight.workedMinutesToday),
            progress: (insight.workedMinutesToday / todayTarget).clamp(0, 1),
            color: NavalgoColors.tide,
            caption: 'Objetivo visual de 8 horas',
          ),
          const SizedBox(height: 14),
          _ActivityProgressRow(
            label: 'Ritmo mensual',
            valueLabel: _formatMinutes(insight.workedMinutesThisMonth),
            progress: (insight.workedMinutesThisMonth / monthTarget).clamp(0, 1),
            color: NavalgoColors.harbor,
            caption: 'Objetivo visual de 160 horas',
          ),
          const SizedBox(height: 14),
          _ActivityProgressRow(
            label: 'Ritmo anual',
            valueLabel: _formatMinutes(insight.workedMinutesThisYear),
            progress: (insight.workedMinutesThisYear / yearTarget).clamp(0, 1),
            color: NavalgoColors.kelp,
            caption: 'Objetivo visual de 1760 horas',
          ),
          const SizedBox(height: 14),
          _ActivityProgressRow(
            label: 'Ausencias frente a la media',
            valueLabel: _absenceComparisonLabel(insight.absenceVsAveragePercent),
            progress: absenceRatio,
            color: insight.absenceVsAveragePercent > 0
                ? NavalgoColors.coral
                : NavalgoColors.kelp,
            caption: 'Comparativa interna de incidencias no vacacionales',
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAdjustmentRequests(BuildContext context) {
    return NavalgoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Solicitudes pendientes de ajuste',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              NavalgoStatusChip(
                label: '${_pendingAdjustmentRequests.length} pendientes',
                color: _pendingAdjustmentRequests.isEmpty
                    ? NavalgoColors.storm
                    : NavalgoColors.sand,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Revisa aquí las solicitudes de este $_roleLabel para no dispersar el control horario.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (_pendingAdjustmentRequests.isEmpty)
            Text(
              'Este $_roleLabel no tiene solicitudes pendientes de revisión.',
            )
          else
            ..._pendingAdjustmentRequests.map((request) {
              final requestedClockIn = request.requestedClockIn;
              final requestedClockOut = request.requestedClockOut;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AdminAdjustmentRequestCard(
                  request: request,
                  workDateLabel: _formatAdjustmentDate(request.workDate),
                  requestedHoursLabel:
                      '${requestedClockIn == null ? '--:--' : _formatAdjustmentHour(requestedClockIn)} - ${requestedClockOut == null ? '--:--' : _formatAdjustmentHour(requestedClockOut)}',
                  workSiteLabel: _workSiteLabel(request.workSite, widget.worker.role),
                  busy: _adjustmentBusy,
                  onApprove: () => _reviewAdjustmentRequest(request, approve: true),
                  onReject: () => _reviewAdjustmentRequest(request, approve: false),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEntries(BuildContext context) {
    final openEntries = _entries.where((entry) => entry.clockOut == null).length;
    final autoClosedEntries =
        _entries.where((entry) => entry.autoCloseReason != null).length;
    final travelEntries =
        _entries.where((entry) => entry.workSite == 'TRAVEL').length;

    return NavalgoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _isCommercial
                      ? 'Jornadas del comercial'
                      : 'Jornadas del trabajador',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_isSaving)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _EntrySummaryChip(
                icon: Icons.calendar_month_outlined,
                label: '${_entries.length} jornadas visibles',
                color: NavalgoColors.tide,
              ),
              _EntrySummaryChip(
                icon: Icons.lock_open_outlined,
                label: '$openEntries abiertas',
                color: NavalgoColors.kelp,
              ),
              _EntrySummaryChip(
                icon: Icons.route_outlined,
                label: '$travelEntries en viaje',
                color: NavalgoColors.harbor,
              ),
              _EntrySummaryChip(
                icon: Icons.auto_fix_high_outlined,
                label: '$autoClosedEntries cierres automáticos',
                color: NavalgoColors.sand,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_entries.isEmpty)
            Text('Todavía no hay jornadas registradas para este $_roleLabel.')
          else
            ..._entries.take(45).map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _TimeEntryAdminCard(
                  entry: entry,
                  onEdit: () => _editEntry(entry),
                  role: widget.worker.role,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkerPhotoCard extends StatelessWidget {
  const _WorkerPhotoCard({required this.photoUrl, required this.token});

  final String photoUrl;
  final String? token;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.isNotEmpty;
    return Container(
      width: 128,
      height: 128,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: NavalgoColors.foam,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: hasPhoto
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                headers: buildMediaHeaders(token),
                errorBuilder: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: NavalgoColors.mist,
      child: const Icon(
        Icons.person_outline_rounded,
        size: 56,
        color: NavalgoColors.tide,
      ),
    );
  }
}

class _QualityGauge extends StatelessWidget {
  const _QualityGauge({
    required this.score,
    required this.color,
    this.compact = false,
  });

  final double score;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 118.0 : 132.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: (score.clamp(0, 100)) / 100,
              strokeWidth: 12,
              backgroundColor: NavalgoColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: NavalgoColors.deepSea,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Calidad',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: NavalgoColors.storm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkerIdentityBlock extends StatelessWidget {
  const _WorkerIdentityBlock({required this.worker});

  final WorkerProfile worker;

  @override
  Widget build(BuildContext context) {
    final speciality = worker.speciality?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          worker.fullName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: NavalgoColors.deepSea,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          (speciality == null || speciality.isEmpty)
              ? 'Sin especialidad'
              : speciality,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: NavalgoColors.storm,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HeroIdentityCard extends StatelessWidget {
  const _HeroIdentityCard({
    required this.worker,
    required this.photoUrl,
    required this.token,
  });

  final WorkerProfile worker;
  final String photoUrl;
  final String? token;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NavalgoColors.shell,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkerPhotoCard(photoUrl: photoUrl, token: token),
          const SizedBox(width: 16),
          Expanded(child: _WorkerIdentityBlock(worker: worker)),
        ],
      ),
    );
  }
}

class _HeroScoreCard extends StatelessWidget {
  const _HeroScoreCard({
    required this.score,
    required this.color,
    required this.currentlyClockedIn,
    required this.isCommercial,
  });

  final double score;
  final Color color;
  final bool currentlyClockedIn;
  final bool isCommercial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NavalgoColors.shell,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _QualityGauge(score: score, color: color, compact: true)),
          const SizedBox(height: 14),
          Text(
            currentlyClockedIn ? 'Jornada abierta' : 'Jornada cerrada',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: NavalgoColors.deepSea,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isCommercial ? 'Seguimiento del perfil comercial' : 'Seguimiento del perfil técnico',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: NavalgoColors.storm,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolvedPeriodCard extends StatelessWidget {
  const _ResolvedPeriodCard({required this.row});

  final WorkerResolvedWorkOrderStatsRow row;

  @override
  Widget build(BuildContext context) {
    final workedHours = row.workedMinutes / 60;
    final reference = math.max(workedHours, row.loggedLaborHours);
    final progress = reference <= 0
        ? 0.0
        : (workedHours / reference).clamp(0, 1).toDouble();

    return NavalgoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: NavalgoColors.deepSea,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _EntrySummaryChip(
                icon: Icons.task_alt_outlined,
                label: '${row.completedWorkOrders} partes cerrados',
                color: NavalgoColors.tide,
              ),
              _EntrySummaryChip(
                icon: Icons.schedule_outlined,
                label: _formatMinutes(row.workedMinutes),
                color: NavalgoColors.harbor,
              ),
              _EntrySummaryChip(
                icon: Icons.construction_outlined,
                label: '${row.loggedLaborHours.toStringAsFixed(1)} h imputadas',
                color: NavalgoColors.kelp,
              ),
              _EntrySummaryChip(
                icon: Icons.insights_outlined,
                label: '${row.averageWorkedHoursPerOrder.toStringAsFixed(1)} h/parte',
                color: NavalgoColors.sand,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ActivityProgressRow(
            label: 'Horas fichadas frente a imputadas',
            valueLabel:
                '${workedHours.toStringAsFixed(1)} h / ${row.loggedLaborHours.toStringAsFixed(1)} h',
            progress: progress,
            color: NavalgoColors.tide,
            caption: 'La barra toma como referencia el mayor de los dos valores.',
          ),
        ],
      ),
    );
  }
}

class _ActivityProgressRow extends StatelessWidget {
  const _ActivityProgressRow({
    required this.label,
    required this.valueLabel,
    required this.progress,
    required this.color,
    required this.caption,
  });

  final String label;
  final String valueLabel;
  final double progress;
  final Color color;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: NavalgoColors.deepSea,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 10,
            backgroundColor: NavalgoColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: NavalgoColors.storm,
          ),
        ),
      ],
    );
  }
}

class _EntrySummaryChip extends StatelessWidget {
  const _EntrySummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeEntryAdminCard extends StatelessWidget {
  const _TimeEntryAdminCard({
    required this.entry,
    required this.onEdit,
    required this.role,
  });

  final TimeEntry entry;
  final VoidCallback onEdit;
  final String? role;

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        entry.clockInLatitude != null && entry.clockInLongitude != null;
    final duration = _entryDurationLabel(entry);
    final statusColor = _entryStatusColor(entry);
    final statusLabel = _entryStatusLabel(entry);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: NavalgoColors.border),
        boxShadow: [
          BoxShadow(
            color: NavalgoColors.deepSea.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  entry.workSite == 'TRAVEL'
                      ? Icons.route_outlined
                      : Icons.handyman_outlined,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(entry.clockIn),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: NavalgoColors.deepSea,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Entrada ${_formatHour(entry.clockIn)} - Salida ${entry.clockOut == null ? '--:--' : _formatHour(entry.clockOut!)}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: NavalgoColors.deepSea,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              NavalgoStatusChip(
                label: statusLabel,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _EntryMetaChip(
                icon: Icons.category_outlined,
                label: _workSiteLabel(entry.workSite, role),
                color: NavalgoColors.tide,
              ),
              if (duration != null)
                _EntryMetaChip(
                  icon: Icons.schedule_outlined,
                  label: duration,
                  color: NavalgoColors.harbor,
                ),
              if (entry.plannedClockOut != null)
                _EntryMetaChip(
                  icon: Icons.alarm_on_outlined,
                  label: 'Previsto ${_formatHour(entry.plannedClockOut!)}',
                  color: NavalgoColors.kelp,
                ),
              if (hasLocation)
                _EntryMetaChip(
                  icon: Icons.gps_fixed_outlined,
                  label:
                      '${entry.clockInLatitude!.toStringAsFixed(5)}, ${entry.clockInLongitude!.toStringAsFixed(5)}',
                  color: NavalgoColors.sand,
                ),
            ],
          ),
          if (entry.autoCloseReason != null) ...[
            const SizedBox(height: 14),
            NavalgoStatusChip(
              label: entry.autoCloseReason == 'PLANNED_END_TIME'
                  ? 'Autocierre por hora prevista'
                  : 'Autocierre fin del dia',
              color: NavalgoColors.sand,
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Ajustar jornada'),
              ),
              if (hasLocation)
                OutlinedButton.icon(
                  onPressed: () => _openClockInLocation(
                    entry.clockInLatitude!,
                    entry.clockInLongitude!,
                  ),
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('Abrir ubicacion'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryMetaChip extends StatelessWidget {
  const _EntryMetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NavalgoColors.deepSea,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAdjustmentRequestCard extends StatelessWidget {
  const _AdminAdjustmentRequestCard({
    required this.request,
    required this.workDateLabel,
    required this.requestedHoursLabel,
    required this.workSiteLabel,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final TimeAdjustmentRequest request;
  final String workDateLabel;
  final String requestedHoursLabel;
  final String workSiteLabel;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final statusColor = _timeAdjustmentStatusColor(request.status);
    return NavalgoPanel(
      tint: statusColor.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.workerName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$workDateLabel · $workSiteLabel · $requestedHoursLabel',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              NavalgoStatusChip(
                label: _timeAdjustmentStatusLabel(request.status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(request.reason, style: Theme.of(context).textTheme.bodyLarge),
          if (request.adminComment != null && request.adminComment!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Comentario: ${request.adminComment}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close_outlined),
                  label: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onApprove,
                  icon: const Icon(Icons.check_outlined),
                  label: const Text('Aprobar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditTimeEntryInput {
  const _EditTimeEntryInput({
    required this.clockIn,
    required this.clockOut,
    required this.plannedClockOut,
    required this.workSite,
  });

  final DateTime clockIn;
  final DateTime? clockOut;
  final DateTime? plannedClockOut;
  final String workSite;
}

class _EditTimeEntryDialog extends StatefulWidget {
  const _EditTimeEntryDialog({required this.entry, required this.role});

  final TimeEntry entry;
  final String? role;

  @override
  State<_EditTimeEntryDialog> createState() => _EditTimeEntryDialogState();
}

class _EditSummaryCard extends StatelessWidget {
  const _EditSummaryCard({
    required this.entry,
    required this.workDate,
    required this.clockInTime,
    required this.clockOutTime,
    required this.plannedClockOutTime,
    required this.workSite,
  });

  final TimeEntry entry;
  final DateTime workDate;
  final TimeOfDay clockInTime;
  final TimeOfDay? clockOutTime;
  final TimeOfDay? plannedClockOutTime;
  final String workSite;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NavalgoColors.shell,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(workDate),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: NavalgoColors.deepSea,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Entrada ${clockInTime.format(context)} · Salida ${clockOutTime?.format(context) ?? 'Sin cerrar'}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: NavalgoColors.deepSea,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _EditSummaryPill(
                icon: Icons.route_outlined,
                label: _workSiteLabel(workSite),
              ),
              _EditSummaryPill(
                icon: Icons.alarm_on_outlined,
                label: plannedClockOutTime == null
                    ? 'Sin hora prevista'
                    : 'Previsto ${plannedClockOutTime!.format(context)}',
              ),
              if (entry.autoCloseReason != null)
                const _EditSummaryPill(
                  icon: Icons.auto_fix_high_outlined,
                  label: 'Registro con autocierre',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditTimeEntryDialogState extends State<_EditTimeEntryDialog> {
  late DateTime _workDate;
  late TimeOfDay _clockInTime;
  TimeOfDay? _clockOutTime;
  TimeOfDay? _plannedClockOutTime;
  late String _workSite;
  String? _error;

  @override
  void initState() {
    super.initState();
    final clockIn = widget.entry.clockIn.toLocal();
    _workDate = DateTime(clockIn.year, clockIn.month, clockIn.day);
    _clockInTime = TimeOfDay.fromDateTime(clockIn);
    _clockOutTime = widget.entry.clockOut == null
        ? null
        : TimeOfDay.fromDateTime(widget.entry.clockOut!.toLocal());
    _plannedClockOutTime = widget.entry.plannedClockOut == null
        ? null
        : TimeOfDay.fromDateTime(widget.entry.plannedClockOut!.toLocal());
    _workSite = widget.entry.workSite;
  }

  @override
  Widget build(BuildContext context) {
    return NavalgoFormDialog(
      eyebrow: 'CONTROL HORARIO',
      title: 'Ajustar jornada',
      maxWidth: 620,
      bodyInPanel: false,
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        NavalgoGradientButton(
          label: 'Guardar ajuste',
          icon: Icons.save_outlined,
          onPressed: _submit,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditSummaryCard(
            entry: widget.entry,
            workDate: _workDate,
            clockInTime: _clockInTime,
            clockOutTime: _clockOutTime,
            plannedClockOutTime: _plannedClockOutTime,
            workSite: _workSite,
          ),
          const SizedBox(height: 18),
          NavalgoPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NavalgoFormFieldBlock(
                  label: 'Fecha de trabajo',
                  child: NavalgoPickerField(
                    label: 'Fecha',
                    prefixIcon: const Icon(Icons.event_outlined),
                    value: _formatDate(_workDate),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _workDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (!mounted || picked == null) {
                        return;
                      }
                      setState(() {
                        _workDate = picked;
                        _error = null;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _TimePickerTile(
                        label: 'Entrada',
                        value: _clockInTime.format(context),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _clockInTime,
                          );
                          if (!mounted || picked == null) {
                            return;
                          }
                          setState(() {
                            _clockInTime = picked;
                            _error = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimePickerTile(
                        label: 'Salida',
                        value: _clockOutTime?.format(context) ?? 'Sin cerrar',
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _clockOutTime ??
                                const TimeOfDay(hour: 17, minute: 0),
                          );
                          if (!mounted || picked == null) {
                            return;
                          }
                          setState(() {
                            _clockOutTime = picked;
                            _error = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                NavalgoFormFieldBlock(
                  label: 'Plan de cierre',
                  child: NavalgoPickerField(
                    label: 'Hora prevista de cierre',
                    prefixIcon: const Icon(Icons.alarm_on_outlined),
                    value: _plannedClockOutTime?.format(context),
                    placeholder: 'No definida',
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _plannedClockOutTime ??
                            const TimeOfDay(hour: 17, minute: 0),
                      );
                      if (!mounted || picked == null) {
                        return;
                      }
                      setState(() {
                        _plannedClockOutTime = picked;
                        _error = null;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 14),
                NavalgoFormFieldBlock(
                  label: 'Tipo de jornada',
                  child: DropdownButtonFormField<String>(
                    initialValue: _workSite,
                    dropdownColor: NavalgoColors.shell,
                    decoration: NavalgoFormStyles.inputDecoration(
                      context,
                      label: 'Tipo de jornada',
                      prefixIcon: const Icon(Icons.route_outlined),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'WORKSHOP',
                        child: Text(widget.role == 'COMERCIAL' ? 'Oficina' : 'Taller'),
                      ),
                      if (widget.role != 'COMERCIAL')
                        const DropdownMenuItem(value: 'TRAVEL', child: Text('Viaje')),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _workSite = value;
                        _error = null;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _clockOutTime = null;
                        _plannedClockOutTime = null;
                        _error = null;
                      });
                    },
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Limpiar salida y hora prevista'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NavalgoColors.coral.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: NavalgoColors.coral.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: NavalgoColors.coral,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: NavalgoColors.deepSea,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    DateTime combine(TimeOfDay time) {
      return DateTime(
        _workDate.year,
        _workDate.month,
        _workDate.day,
        time.hour,
        time.minute,
      );
    }

    final clockIn = combine(_clockInTime);
    final clockOut = _clockOutTime == null ? null : combine(_clockOutTime!);
    final plannedClockOut = _plannedClockOutTime == null
        ? null
        : combine(_plannedClockOutTime!);

    if (clockOut != null && clockOut.isBefore(clockIn)) {
      setState(() {
        _error = 'La salida no puede ser anterior a la entrada.';
      });
      return;
    }
    if (plannedClockOut != null && plannedClockOut.isBefore(clockIn)) {
      setState(() {
        _error = 'La hora prevista no puede ser anterior a la entrada.';
      });
      return;
    }

    Navigator.of(context).pop(
      _EditTimeEntryInput(
        clockIn: clockIn,
        clockOut: clockOut,
        plannedClockOut: plannedClockOut,
        workSite: _workSite,
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NavalgoPickerField(
      label: label,
      prefixIcon: const Icon(Icons.schedule_outlined),
      value: value,
      onTap: onTap,
    );
  }
}

class _EditSummaryPill extends StatelessWidget {
  const _EditSummaryPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NavalgoColors.mist,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: NavalgoColors.tide),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NavalgoColors.deepSea,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color _scoreColor(double score) {
  if (score >= 80) {
    return NavalgoColors.kelp;
  }
  if (score >= 60) {
    return NavalgoColors.harbor;
  }
  if (score >= 40) {
    return NavalgoColors.sand;
  }
  return NavalgoColors.coral;
}

String _timeAdjustmentStatusLabel(String status) {
  switch (status) {
    case 'APPROVED':
      return 'Aprobada';
    case 'REJECTED':
      return 'Rechazada';
    default:
      return 'Pendiente';
  }
}

Color _timeAdjustmentStatusColor(String status) {
  switch (status) {
    case 'APPROVED':
      return NavalgoColors.kelp;
    case 'REJECTED':
      return NavalgoColors.coral;
    default:
      return NavalgoColors.sand;
  }
}

String _formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '${hours}h ${remainingMinutes.toString().padLeft(2, '0')}m';
}

String _formatAdjustmentDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
}

String _formatAdjustmentHour(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _formatHour(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _absenceComparisonLabel(double percent) {
  if (percent.abs() < 0.05) {
    return 'En la media del equipo';
  }
  if (percent > 0) {
    return '${percent.toStringAsFixed(0)}% más ausencias que la media';
  }
  return '${percent.abs().toStringAsFixed(0)}% menos ausencias que la media';
}

String _workSiteLabel(String workSite, [String? role]) {
  if (workSite == 'TRAVEL') return 'Viaje';
  return role == 'COMERCIAL' ? 'Oficina' : 'Taller';
}

String _entryStatusLabel(TimeEntry entry) {
  if (entry.clockOut == null) {
    return 'Abierta';
  }
  if (entry.autoCloseReason != null) {
    return 'Autocierre';
  }
  return 'Cerrada';
}

Color _entryStatusColor(TimeEntry entry) {
  if (entry.clockOut == null) {
    return NavalgoColors.kelp;
  }
  if (entry.autoCloseReason != null) {
    return NavalgoColors.sand;
  }
  return NavalgoColors.tide;
}

String? _entryDurationLabel(TimeEntry entry) {
  final end = entry.clockOut ?? entry.plannedClockOut;
  if (end == null) {
    return null;
  }
  /*

  Widget _buildPendingAdjustmentRequests(BuildContext context) {
    return NavalgoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Solicitudes pendientes de ajuste',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              NavalgoStatusChip(
                label: '${_pendingAdjustmentRequests.length} pendientes',
                color: _pendingAdjustmentRequests.isEmpty
                    ? NavalgoColors.storm
                    : NavalgoColors.sand,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Revisa aquí las solicitudes de este trabajador para no dispersar el control horario.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (_pendingAdjustmentRequests.isEmpty)
            const Text(
              'Este trabajador no tiene solicitudes pendientes de revisión.',
            )
          else
            ..._pendingAdjustmentRequests.map((request) {
              final requestedClockIn = request.requestedClockIn;
              final requestedClockOut = request.requestedClockOut;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AdminAdjustmentRequestCard(
                  request: request,
                  workDateLabel: _formatAdjustmentDate(request.workDate),
                  requestedHoursLabel:
                      '${requestedClockIn == null ? '--:--' : _formatAdjustmentHour(requestedClockIn)} - ${requestedClockOut == null ? '--:--' : _formatAdjustmentHour(requestedClockOut)}',
                  workSiteLabel: _workSiteLabel(request.workSite, widget.worker.role),
                  busy: _adjustmentBusy,
                  onApprove: () => _reviewAdjustmentRequest(request, approve: true),
                  onReject: () => _reviewAdjustmentRequest(request, approve: false),
                ),
              );
            }),
        ],
      ),
    );
  }
  */
  final difference = end.difference(entry.clockIn).inMinutes;
  if (difference <= 0) {
    return null;
  }
  return _formatMinutes(difference);
}

Future<void> _openClockInLocation(double latitude, double longitude) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
