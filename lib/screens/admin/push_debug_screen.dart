import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/push_debug.dart';
import '../../services/push_debug_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../utils/app_toast.dart';
import '../../utils/browser_notification.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

class PushDebugScreen extends StatefulWidget {
  const PushDebugScreen({super.key});

  @override
  State<PushDebugScreen> createState() => _PushDebugScreenState();
}

class _PushDebugScreenState extends State<PushDebugScreen> {
  PushDebugStatus? _status;
  List<PushDebugToken> _tokens = const <PushDebugToken>[];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData({bool showLoader = true}) async {
    final token = context.read<SessionViewModel>().token;
    if (token == null || token.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'No hay sesión activa.';
      });
      return;
    }

    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final service = context.read<PushDebugService>();
      final status = await service.getStatus(token);
      final tokens = await service.getTokens(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _tokens = tokens;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _sendSelfTest() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() => _sending = true);
    try {
      await context.read<PushDebugService>().sendSelfTest(token);
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Push de prueba enviada.');
      await _loadData(showLoader: false);
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo enviar la push de prueba: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _sendBrowserLocalTest() async {
    try {
      await showBrowserNotification(
        title: 'NavalGO',
        body: 'Prueba local de notificaciones web.',
        tag: 'navalgo-browser-local-test',
      );
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Prueba local lanzada en el navegador.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo lanzar la prueba local: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: NavalgoColors.pageGradient),
      child: RefreshIndicator(
        onRefresh: () => _loadData(showLoader: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            NavalgoPageIntro(
              eyebrow: 'PUSH DEBUG',
              title: 'Diagnóstico de notificaciones',
              subtitle:
                  'Verifica credenciales Firebase, tokens activos y lanza pruebas sin salir de NavalGO.',
              trailing: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => _loadData(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Actualizar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _loading || _sending ? null : _sendSelfTest,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(_sending ? 'Enviando...' : 'Push de prueba'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: NavalgoColors.tide,
                    ),
                  ),
                  if (kIsWeb)
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _sendBrowserLocalTest,
                      icon: const Icon(Icons.desktop_windows_outlined),
                      label: const Text('Prueba local web'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _buildErrorCard()
            else ...[
              _buildMetricGrid(),
              const SizedBox(height: 20),
              _buildStatusCard(),
              const SizedBox(height: 20),
              _buildTokensCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NavalgoColors.coral.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No se pudo cargar el diagnóstico',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(_error ?? 'Error desconocido'),
        ],
      ),
    );
  }

  Widget _buildMetricGrid() {
    final status = _status!;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1280
        ? 4
        : width >= 900
        ? 3
        : width >= 640
        ? 2
        : 1;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: width >= 900 ? 1.6 : 1.45,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        NavalgoMetricCard(
          label: 'Firebase',
          value: status.firebaseInitialized ? 'Inicializado' : 'Pendiente',
          icon: const Icon(Icons.cloud_done_outlined),
          accent: status.firebaseInitialized
              ? NavalgoColors.kelp
              : NavalgoColors.coral,
          note: status.firebaseEnabled ? 'Habilitado' : 'Deshabilitado',
        ),
        NavalgoMetricCard(
          label: 'Tokens activos',
          value: '${status.activeTokenCount}',
          icon: const Icon(Icons.phonelink_lock_outlined),
          accent: NavalgoColors.tide,
          note: _platformSummary(status),
        ),
        NavalgoMetricCard(
          label: 'Último envío',
          value: _formatDateTime(status.lastSendSuccessAt) ?? 'Sin éxito',
          icon: const Icon(Icons.notifications_active_outlined),
          accent: status.lastSendError == null
              ? NavalgoColors.kelp
              : NavalgoColors.harbor,
          note:
              'Solicitados ${status.lastRequestedTokenCount} · inválidos ${status.lastInvalidTokenCount}',
        ),
        NavalgoMetricCard(
          label: 'Credenciales',
          value: status.credentialSource,
          icon: const Icon(Icons.key_outlined),
          accent: status.credentialsReadable
              ? NavalgoColors.kelp
              : NavalgoColors.coral,
          note: status.credentialsReadable ? 'Legibles' : 'No accesibles',
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    final status = _status!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: NavalgoColors.border),
        boxShadow: [
          BoxShadow(
            color: NavalgoColors.deepSea.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NavalgoSectionHeader(
            title: 'Estado backend',
            subtitle:
                'Aquí ves si el backend está listo para enviar a Firebase o si se está cortando antes.',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatusPill(
                label: status.firebaseEnabled ? 'Firebase ON' : 'Firebase OFF',
                ok: status.firebaseEnabled,
              ),
              _buildStatusPill(
                label: status.credentialsReadable
                    ? 'Credenciales OK'
                    : 'Credenciales KO',
                ok: status.credentialsReadable,
              ),
              _buildStatusPill(
                label: status.firebaseInitialized
                    ? 'SDK inicializado'
                    : 'SDK no inicializado',
                ok: status.firebaseInitialized,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DebugRow(
            label: 'Último intento de init',
            value: _formatDateTime(status.lastInitializationAttemptAt) ?? '-',
          ),
          _DebugRow(
            label: 'Último init correcto',
            value: _formatDateTime(status.lastInitializationSuccessAt) ?? '-',
          ),
          _DebugRow(
            label: 'Último intento de envío',
            value: _formatDateTime(status.lastSendAttemptAt) ?? '-',
          ),
          _DebugRow(
            label: 'Último envío correcto',
            value: _formatDateTime(status.lastSendSuccessAt) ?? '-',
          ),
          _DebugRow(
            label: 'Error init',
            value: _normalizeText(status.lastInitializationError),
            highlight: status.lastInitializationError != null,
          ),
          _DebugRow(
            label: 'Error envío',
            value: _normalizeText(status.lastSendError),
            highlight: status.lastSendError != null,
          ),
        ],
      ),
    );
  }

  Widget _buildTokensCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NavalgoSectionHeader(
            title: 'Tokens activos',
            subtitle:
                'Si un dispositivo no aparece aquí, el fallo está en permisos, token FCM o registro en backend.',
            action: Text(
              '${_tokens.length} dispositivo(s)',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: NavalgoColors.storm,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_tokens.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: NavalgoColors.foam,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'No hay tokens activos registrados ahora mismo.',
              ),
            )
          else
            ..._tokens.map(_buildTokenTile),
        ],
      ),
    );
  }

  Widget _buildTokenTile(PushDebugToken item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NavalgoColors.foam,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.workerName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildPlatformBadge(item.platform),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.workerEmail,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: NavalgoColors.storm),
          ),
          const SizedBox(height: 10),
          _DebugRow(label: 'Token', value: item.maskedToken),
          _DebugRow(
            label: 'Última actividad',
            value: _formatDateTime(item.lastSeenAt) ?? '-',
          ),
          _DebugRow(
            label: 'Registrado',
            value: _formatDateTime(item.createdAt) ?? '-',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({required String label, required bool ok}) {
    final color = ok ? NavalgoColors.kelp : NavalgoColors.coral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildPlatformBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: NavalgoColors.tide.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: NavalgoColors.tide,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _platformSummary(PushDebugStatus status) {
    if (status.activeTokensByPlatform.isEmpty) {
      return 'Sin dispositivos';
    }
    return status.activeTokensByPlatform
        .map((item) => '${item.platform}: ${item.count}')
        .join(' · ');
  }

  String _normalizeText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return '-';
    }
    return normalized;
  }

  String? _formatDateTime(DateTime? value) {
    if (value == null) {
      return null;
    }
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NavalgoColors.storm,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: highlight ? NavalgoColors.coral : NavalgoColors.deepSea,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
