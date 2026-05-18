import 'package:flutter/material.dart';

import '../models/time_entry.dart';
import '../theme/navalgo_theme.dart';
import '../utils/media_url.dart';
import 'navalgo_ui.dart';

class TeamLeaderboardPanel extends StatelessWidget {
  const TeamLeaderboardPanel({
    super.key,
    required this.entries,
    required this.token,
    this.title = 'Top 3 del equipo',
    this.subtitle =
        'Ranking conjunto entre comerciales y taller según la puntuación global de rendimiento.',
  });

  final List<WorkerTimeTrackingStats> entries;
  final String? token;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return NavalgoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NavalgoSectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Text(
              'Todavía no hay datos suficientes para mostrar el ranking.',
            )
          else
            ...entries.asMap().entries.map((entry) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == entries.length - 1 ? 0 : 12,
                ),
                child: _LeaderboardTile(
                  position: entry.key + 1,
                  entry: entry.value,
                  token: token,
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.position,
    required this.entry,
    required this.token,
  });

  final int position;
  final WorkerTimeTrackingStats entry;
  final String? token;

  @override
  Widget build(BuildContext context) {
    final accent = switch (position) {
      1 => NavalgoColors.sand,
      2 => NavalgoColors.harbor,
      _ => NavalgoColors.coral,
    };
    final resolvedPhotoUrl = resolveMediaUrl(entry.photoUrl);
    final photoHeaders = buildMediaHeaders(token);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 360;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LeaderboardIdentity(
                      expandContent: false,
                      position: position,
                      accent: accent,
                      resolvedPhotoUrl: resolvedPhotoUrl,
                      photoHeaders: photoHeaders,
                      workerName: entry.workerName,
                      workerRole: entry.workerRole,
                    ),
                    const SizedBox(height: 12),
                    _LeaderboardScore(
                      accent: accent,
                      score: entry.qualityScore,
                      alignment: CrossAxisAlignment.start,
                    ),
                  ],
                )
              : Row(
                  children: [
                    _LeaderboardIdentity(
                      expandContent: true,
                      position: position,
                      accent: accent,
                      resolvedPhotoUrl: resolvedPhotoUrl,
                      photoHeaders: photoHeaders,
                      workerName: entry.workerName,
                      workerRole: entry.workerRole,
                    ),
                    const SizedBox(width: 12),
                    _LeaderboardScore(
                      accent: accent,
                      score: entry.qualityScore,
                      alignment: CrossAxisAlignment.end,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _LeaderboardIdentity extends StatelessWidget {
  const _LeaderboardIdentity({
    required this.expandContent,
    required this.position,
    required this.accent,
    required this.resolvedPhotoUrl,
    required this.photoHeaders,
    required this.workerName,
    required this.workerRole,
  });

  final bool expandContent;
  final int position;
  final Color accent;
  final String resolvedPhotoUrl;
  final Map<String, String>? photoHeaders;
  final String workerName;
  final String workerRole;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              '$position',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        CircleAvatar(
          radius: 24,
          backgroundColor: NavalgoColors.mist,
          foregroundImage: resolvedPhotoUrl.isEmpty
              ? null
              : NetworkImage(resolvedPhotoUrl, headers: photoHeaders),
          child: const Icon(Icons.person_outline, color: NavalgoColors.tide),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workerName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: NavalgoColors.deepSea,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                workerRole == 'COMERCIAL' ? 'Comercial' : 'Taller',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );

    if (expandContent) {
      return Expanded(child: content);
    }
    return content;
  }
}

class _LeaderboardScore extends StatelessWidget {
  const _LeaderboardScore({
    required this.accent,
    required this.score,
    required this.alignment,
  });

  final Color accent;
  final double score;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          score.toStringAsFixed(1),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'puntos',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: NavalgoColors.storm),
        ),
      ],
    );
  }
}
