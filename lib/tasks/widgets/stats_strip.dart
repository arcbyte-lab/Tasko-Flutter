import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../task_rules.dart';

/// The black workload strip under the top bar (hifi H12, 80 tall): MY WORK
/// and DEADLINES, two counts each. It never minimizes.
class StatsStrip extends StatelessWidget {
  const StatsStrip(this.workload, {super.key});

  final Workload workload;

  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    color: Colors.black,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: _Group('MY WORK', [
            _Stat(workload.inProgress, 'In progress', 0xFF3370D4, 0xFF2563EB),
            _Stat(workload.toReview, 'To review', 0xFFF27216, 0xFFF97316),
          ]),
        ),
        Expanded(
          child: _Group('DEADLINES', [
            _Stat(workload.dueSoon, 'Due soon', 0xFFFCD34D, 0xFFF59E0B),
            _Stat(workload.overdue, 'Overdue', 0xFFF87171, 0xFFEF4444),
          ]),
        ),
      ],
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group(this.label, this.stats);

  final String label;
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: AppColors.placeholder,
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          for (final s in stats) ...[Expanded(child: s)],
        ],
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.count, this.label, this.countColor, this.dotColor);

  final int count;
  final String label;
  final int countColor;
  final int dotColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$count',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(countColor),
        ),
      ),
      Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Color(dotColor),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.placeholder,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
