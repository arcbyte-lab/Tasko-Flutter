import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models.dart';
import '../view_options.dart';
import 'pickers.dart';

/// Group, sort and filter (arcbyte lofi T5, hifi H2). Resolves to the
/// applied options, or null when dismissed.
Future<ViewOptions?> showViewOptionsSheet(
  BuildContext context, {
  required ViewOptions current,
  required bool personal,
  required List<Member> members,
  required int meId,
}) => showPicker<ViewOptions>(
  context,
  _ViewOptionsSheet(
    initial: current,
    personal: personal,
    members: members,
    meId: meId,
  ),
);

class _ViewOptionsSheet extends StatefulWidget {
  const _ViewOptionsSheet({
    required this.initial,
    required this.personal,
    required this.members,
    required this.meId,
  });

  final ViewOptions initial;
  final bool personal;
  final List<Member> members;
  final int meId;

  @override
  State<_ViewOptionsSheet> createState() => _ViewOptionsSheetState();
}

class _ViewOptionsSheetState extends State<_ViewOptionsSheet> {
  late ViewOptions _v = widget.initial;

  void _set(ViewOptions v) => setState(() => _v = v);

  @override
  Widget build(BuildContext context) {
    // Personal tasks have no assignee and no review.
    final groups = GroupBy.values.where(
      (g) => !(widget.personal && g == GroupBy.assignee),
    );
    final statuses = widget.personal
        ? const [TaskStatus.todo, TaskStatus.inProgress, TaskStatus.done]
        : const [
            TaskStatus.waiting,
            TaskStatus.inProgress,
            TaskStatus.review,
            TaskStatus.done,
          ];
    String nameOf(Member m) => m.user.id == widget.meId ? 'me' : m.user.name;
    final assignee = widget.members
        .where((m) => m.user.id == _v.assigneeId)
        .firstOrNull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('GROUP BY', style: groupLabelStyle()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in groups)
                  _Choice(
                    label: g.label,
                    selected: _v.groupBy == g,
                    onTap: () => _set(_v.copyWith(groupBy: g)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('SORT BY', style: groupLabelStyle()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final s in SortBy.values)
                  _Choice(
                    label: s.label,
                    selected: _v.sortBy == s,
                    onTap: () => _set(_v.copyWith(sortBy: s)),
                  ),
                _Direction(
                  descending: _v.descending,
                  onChanged: (d) => _set(_v.copyWith(descending: d)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('FILTER', style: groupLabelStyle()),
            _Filter<Priority?>(
              label: 'priority',
              value: _v.priority?.name ?? 'any',
              options: {
                null: 'any',
                for (final p in Priority.values) p: p.name,
              },
              onSelected: (p) => _set(_v.copyWith(priority: () => p)),
            ),
            _Filter<TaskStatus?>(
              label: 'status',
              value: _v.status?.label ?? 'any',
              options: {null: 'any', for (final s in statuses) s: s.label},
              onSelected: (s) => _set(_v.copyWith(status: () => s)),
            ),
            if (!widget.personal)
              _Filter<int?>(
                label: 'assignee',
                value: assignee == null ? 'anyone' : nameOf(assignee),
                options: {
                  null: 'anyone',
                  for (final m in widget.members) m.user.id: nameOf(m),
                },
                onSelected: (id) => _set(_v.copyWith(assigneeId: () => id)),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: () => _set(ViewOptions.defaults),
                  style: TextButton.styleFrom(
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                    ),
                  ),
                  child: const Text('reset'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _v),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// H1 chip: selected is primary with white text, others #F3F4F6.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.primary : AppColors.secondary,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.secondaryForeground,
            ),
          ),
        ),
      ),
    ),
  );
}

/// "asc | desc": a #F3F4F6 track with a white selected segment.
class _Direction extends StatelessWidget {
  const _Direction({required this.descending, required this.onChanged});

  final bool descending;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget part(String label, bool value) {
      final on = descending == value;
      return Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: on
                    ? AppColors.foreground
                    : AppColors.secondaryForeground,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [part('asc', false), part('desc', true)],
      ),
    );
  }
}

/// A label, then the value and a chevron; tapping opens the choices.
class _Filter<T> extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String value;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;

  @override
  // Menu values are indexes: a null value ("any") would count as a cancel.
  Widget build(BuildContext context) => PopupMenuButton<int>(
    tooltip: label,
    color: AppColors.background,
    position: PopupMenuPosition.under,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: const BorderSide(color: AppColors.border),
    ),
    onSelected: (i) => onSelected(options.keys.elementAt(i)),
    itemBuilder: (_) => [
      for (final (i, text) in options.values.indexed)
        PopupMenuItem(value: i, child: Text(text)),
    ],
    child: Container(
      height: 44,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.expand_more,
            size: 20,
            color: AppColors.mutedForeground,
          ),
        ],
      ),
    ),
  );
}
