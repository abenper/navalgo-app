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
    this.title = 'Top 3 de fichaje',
    this.subtitle =
        'Ranking mensual segun cierre manual de jornada, ausencias registradas y dias sin fichaje.',
  });

  final List<WorkerTimeTrackingStats> entries;
  final String? token;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final showMonthlyWinner = DateTime.now().day == 1 && entries.isNotEmpty;

    return NavalgoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NavalgoSectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Text(
              'Todavia no hay datos suficientes para mostrar el ranking.',
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
                  isMonthlyWinner: showMonthlyWinner && entry.key == 0,
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
    required this.isMonthlyWinner,
  });

  final int position;
  final WorkerTimeTrackingStats entry;
  final String? token;
  final bool isMonthlyWinner;

  @override
  Widget build(BuildContext context) {
    final accent = switch (position) {
      1 => NavalgoColors.sand,
      2 => NavalgoColors.harbor,
      _ => NavalgoColors.coral,
    };
    final resolvedPhotoUrl = resolveMediaUrl(entry.photoUrl);
    final photoHeaders = buildMediaHeaders(token);
    final tileDecoration = BoxDecoration(
      color: accent.withValues(alpha: isMonthlyWinner ? 0.12 : 0.08),
      gradient: isMonthlyWinner
          ? LinearGradient(
              colors: [
                NavalgoColors.sand.withValues(alpha: 0.24),
                Colors.white.withValues(alpha: 0.86),
                accent.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: accent.withValues(alpha: isMonthlyWinner ? 0.32 : 0.16),
      ),
      boxShadow: isMonthlyWinner
          ? [
              BoxShadow(
                color: NavalgoColors.sand.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ]
          : null,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 360;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: tileDecoration,
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
                      isMonthlyWinner: isMonthlyWinner,
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
                      isMonthlyWinner: isMonthlyWinner,
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
    required this.isMonthlyWinner,
  });

  final bool expandContent;
  final int position;
  final Color accent;
  final String resolvedPhotoUrl;
  final Map<String, String>? photoHeaders;
  final String workerName;
  final String workerRole;
  final bool isMonthlyWinner;

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
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: NavalgoColors.mist,
              foregroundImage: resolvedPhotoUrl.isEmpty
                  ? null
                  : NetworkImage(resolvedPhotoUrl, headers: photoHeaders),
              child: const Icon(
                Icons.person_outline,
                color: NavalgoColors.tide,
              ),
            ),
            if (isMonthlyWinner)
              Positioned(
                top: -13,
                right: -9,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: NavalgoColors.sand,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
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
              if (isMonthlyWinner) ...[
                const SizedBox(height: 6),
                _MonthlyWinnerBadge(workerName: workerName),
              ],
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

class _MonthlyWinnerBadge extends StatelessWidget {
  const _MonthlyWinnerBadge({required this.workerName});

  final String workerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: NavalgoColors.sand.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NavalgoColors.sand.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 15,
            color: NavalgoColors.sand,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Ganador/a de este mes: $workerName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: NavalgoColors.deepSea,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
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
          'fichaje',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: NavalgoColors.storm),
        ),
      ],
    );
  }
}
