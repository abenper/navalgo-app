import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/budget.dart';
import '../theme/navalgo_theme.dart';

class BudgetTimeline extends StatelessWidget {
  const BudgetTimeline({super.key, required this.events});

  final List<BudgetTimelineEntry> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text(
        'Aún no hay eventos registrados para este presupuesto.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: NavalgoColors.storm),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          _BudgetTimelineEventTile(
            event: events[i],
            isLast: i == events.length - 1,
          ),
      ],
    );
  }
}

class _BudgetTimelineEventTile extends StatelessWidget {
  const _BudgetTimelineEventTile({required this.event, required this.isLast});

  final BudgetTimelineEntry event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = _eventScheme(event.eventType);
    final dateLabel = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(event.createdAt.toLocal());
    final note = event.note?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 26,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: scheme.color,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 44,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: NavalgoColors.border,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scheme.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: NavalgoColors.deepSea,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NavalgoColors.storm,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_actorRoleLabel(event.actorRole)}: ${event.actorName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NavalgoColors.storm,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      note,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: NavalgoColors.deepSea,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static ({String label, Color color}) _eventScheme(String type) {
    switch (type) {
      case 'UPDATED':
        return (label: 'Borrador actualizado', color: NavalgoColors.harbor);
      case 'SENT':
        return (label: 'Enviado al cliente', color: NavalgoColors.sand);
      case 'ACCEPTED':
        return (label: 'Presupuesto aceptado', color: NavalgoColors.kelp);
      case 'REJECTED':
        return (label: 'Presupuesto rechazado', color: NavalgoColors.coral);
      case 'VESSEL_LINKED':
        return (label: 'Embarcación vinculada', color: NavalgoColors.tide);
      case 'CANCELLED':
        return (label: 'Presupuesto cancelado', color: NavalgoColors.storm);
      default:
        return (label: 'Borrador creado', color: NavalgoColors.deepSea);
    }
  }

  static String _actorRoleLabel(String role) {
    switch (role) {
      case 'CLIENT':
        return 'Cliente';
      case 'COMERCIAL':
        return 'Comercial';
      case 'ADMIN':
        return 'Administrador';
      default:
        return 'Sistema';
    }
  }
}
