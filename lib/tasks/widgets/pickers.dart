import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models.dart';
import '../task_rules.dart';

/// Opens [child] as a second sheet over the create sheet. Resolves to the
/// value passed to [PickerFrame.onDone], or null on cancel.
Future<T?> showPicker<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => child,
    );

/// A picker's label, body, then "cancel" and "done" side by side.
class PickerFrame extends StatelessWidget {
  const PickerFrame({
    super.key,
    required this.label,
    required this.child,
    required this.onDone,
  });

  final String label;
  final Widget child;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );
    // Inter again: a button's textStyle replaces the theme's, family included.
    const text = TextStyle(
      fontFamily: 'Inter',
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: groupLabelStyle()),
            const SizedBox(height: 8),
            Flexible(child: child),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: shape,
                      foregroundColor: AppColors.foreground,
                      side: const BorderSide(color: AppColors.border),
                      textStyle: text,
                    ),
                    child: const Text('cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onDone,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: shape,
                      textStyle: text,
                    ),
                    child: const Text('done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 1 to 4 rising bars; urgent is red, the rest primary.
class PriorityBars extends StatelessWidget {
  const PriorityBars(this.priority, {super.key});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final fill = priority == Priority.urgent
        ? AppColors.destructive
        : AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 3,
            height: 6.0 + i * 3,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: i <= priority.index ? fill : AppColors.controlBorder,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}

class PriorityPicker extends StatefulWidget {
  const PriorityPicker({super.key, required this.initial});

  final Priority initial;

  @override
  State<PriorityPicker> createState() => _PriorityPickerState();
}

class _PriorityPickerState extends State<PriorityPicker> {
  late Priority _value = widget.initial;

  @override
  Widget build(BuildContext context) => PickerFrame(
    label: 'PRIORITY',
    onDone: () => Navigator.pop(context, _value),
    child: RadioGroup<Priority>(
      groupValue: _value,
      onChanged: (v) => setState(() => _value = v!),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in Priority.values)
            InkWell(
              onTap: () => setState(() => _value = p),
              child: Container(
                height: 46,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    PriorityBars(p),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(p.name, style: const TextStyle(fontSize: 15)),
                    ),
                    Radio<Priority>(value: p),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// A month grid and a time. A new date starts at 09:00 (as in Santian).
class DueDatePicker extends StatefulWidget {
  const DueDatePicker({super.key, required this.initial, required this.today});

  final DateTime? initial;
  final DateTime today;

  @override
  State<DueDatePicker> createState() => _DueDatePickerState();
}

class _DueDatePickerState extends State<DueDatePicker> {
  late DateTime? _day = widget.initial;
  late TimeOfDay _time = widget.initial == null
      ? const TimeOfDay(hour: 9, minute: 0)
      : TimeOfDay.fromDateTime(widget.initial!);
  late DateTime _month = DateTime(
    (widget.initial ?? widget.today).year,
    (widget.initial ?? widget.today).month,
  );

  @override
  Widget build(BuildContext context) {
    final leading = _month.weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((leading + days) / 7).ceil();
    const muted = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.mutedForeground,
    );

    Widget cell(int index) {
      final day = index - leading + 1;
      if (day < 1 || day > days) return const Expanded(child: SizedBox());
      final date = DateTime(_month.year, _month.month, day);
      final selected = _day != null && isSameDay(_day!, date);
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: 'Due $day',
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => setState(() => _day = date),
            child: SizedBox(
              height: 40,
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : null,
                    border: !selected && isSameDay(date, widget.today)
                        ? Border.all(color: AppColors.foreground)
                        : null,
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 15,
                      color: selected ? Colors.white : AppColors.foreground,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return PickerFrame(
      label: 'DUE DATE',
      onDone: () {
        final d = _day;
        Navigator.pop(
          context,
          d == null
              ? null
              : DateTime(d.year, d.month, d.day, _time.hour, _time.minute),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${monthNames[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(child: Text(d, style: muted)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(children: [for (var c = 0; c < 7; c++) cell(r * 7 + c)]),
          const Divider(height: 17),
          Row(
            children: [
              const Expanded(
                child: Text('time', style: TextStyle(fontSize: 15)),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (t != null) setState(() => _time = t);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(
                  Icons.schedule,
                  size: 18,
                  color: AppColors.mutedForeground,
                ),
                label: Text(formatTime(_time)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String formatTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Search, then the members with the current user first, labelled "me".
class AssigneePicker extends StatefulWidget {
  const AssigneePicker({
    super.key,
    required this.members,
    required this.initial,
  });

  final List<Member> members;
  final Member? initial;

  @override
  State<AssigneePicker> createState() => _AssigneePickerState();
}

class _AssigneePickerState extends State<AssigneePicker> {
  late Member? _value = widget.initial;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final me = widget.members.firstOrNull;
    final shown = widget.members
        .where((m) => m.user.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return PickerFrame(
      label: 'ASSIGNEE',
      onDone: () => Navigator.pop(context, _value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'search members',
              hintStyle: const TextStyle(color: AppColors.placeholder),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.mutedForeground,
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final m in shown)
                  _MemberRow(
                    member: m,
                    isMe: m == me,
                    selected: m.user.id == _value?.user.id,
                    onTap: () => setState(() => _value = m),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isMe,
    required this.selected,
    required this.onTap,
  });

  final Member member;
  final bool isMe;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.accent : Colors.transparent,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isMe ? AppColors.primary : AppColors.accent,
              child: Text(
                isMe ? 'M' : member.user.name[0],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isMe ? Colors.white : AppColors.accentForeground,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? 'me' : member.user.name,
                    style: const TextStyle(fontSize: 15),
                  ),
                  Text(
                    member.role,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check, color: AppColors.primary),
          ],
        ),
      ),
    ),
  );
}
