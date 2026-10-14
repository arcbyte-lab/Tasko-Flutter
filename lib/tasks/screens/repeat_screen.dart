import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../models.dart';
import '../task_rules.dart';
import '../widgets/pickers.dart';

/// Pushes the repeat screen for a task due on [due] (arcbyte hifi H5).
/// Resolves to null on back, `(null,)` to stop repeating, or the new rule.
/// The time and the first date are the task's due date, so the screen has
/// no "at" or "starts" rows.
Future<(Repeat?,)?> openRepeatScreen(
  BuildContext context, {
  required Repeat? initial,
  required DateTime due,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => RepeatScreen(initial: initial, due: due),
  ),
);

enum _Ends { never, on, after }

class RepeatScreen extends StatefulWidget {
  const RepeatScreen({super.key, required this.initial, required this.due});

  final Repeat? initial;
  final DateTime due;

  @override
  State<RepeatScreen> createState() => _RepeatScreenState();
}

class _RepeatScreenState extends State<RepeatScreen> {
  late final _r = widget.initial;
  late final _every = TextEditingController(text: '${_r?.every ?? 1}');
  late final _count = TextEditingController(text: '${_r?.count ?? 10}');
  late RepeatUnit _unit = _r?.unit ?? RepeatUnit.week;
  late final Set<int> _weekdays = {
    ...(_r?.weekdays ?? [widget.due.weekday]),
  };
  late DateTime? _until = _r?.until;
  late _Ends _ends = _r?.count != null
      ? _Ends.after
      : _r?.until != null
      ? _Ends.on
      : _Ends.never;

  @override
  void dispose() {
    _every.dispose();
    _count.dispose();
    super.dispose();
  }

  /// What the fields say now. An "on" with no date picked means never.
  Repeat get _value => Repeat(
    every: (int.tryParse(_every.text) ?? 1).clamp(1, 999),
    unit: _unit,
    weekdays: _unit == RepeatUnit.week ? (_weekdays.toList()..sort()) : [],
    until: _ends == _Ends.on ? _until : null,
    count: _ends == _Ends.after
        ? (int.tryParse(_count.text) ?? 1).clamp(1, 999)
        : null,
  );

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.mutedForeground,
    );
    const divider = Divider(height: 25);
    final time = formatTime(TimeOfDay.fromDateTime(widget.due));
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.foreground,
        titleSpacing: 0,
        title: const Text(
          'repeat',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, (_value,)),
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15),
            ),
            child: const Text('done'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              const Expanded(child: Text('every', style: label)),
              _NumberBox(_every, onChanged: () => setState(() {})),
              const SizedBox(width: 8),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: _fieldBox,
                child: DropdownButton<RepeatUnit>(
                  value: _unit,
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: AppColors.foreground,
                  ),
                  items: [
                    for (final u in RepeatUnit.values)
                      DropdownMenuItem(value: u, child: Text(u.name)),
                  ],
                  onChanged: (u) => setState(() => _unit = u!),
                ),
              ),
            ],
          ),
          if (_unit == RepeatUnit.week) ...[
            divider,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (var d = 1; d <= 7; d++) _weekdayChip(d)],
            ),
          ],
          divider,
          const Text('ends', style: label),
          RadioGroup<_Ends>(
            groupValue: _ends,
            onChanged: (v) => setState(() => _ends = v!),
            child: Column(
              children: [
                _endsRow(_Ends.never, const [Text('never')]),
                _endsRow(_Ends.on, [
                  const Text('on'),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _pickUntil,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _until == null
                          ? AppColors.placeholder
                          : AppColors.foreground,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      _until == null ? 'pick date' : shortDate(_until!, now),
                    ),
                  ),
                ]),
                _endsRow(_Ends.after, [
                  const Text('after'),
                  const SizedBox(width: 12),
                  _NumberBox(
                    _count,
                    onChanged: () => setState(() => _ends = _Ends.after),
                  ),
                  const SizedBox(width: 12),
                  const Flexible(child: Text('occurrences')),
                ]),
              ],
            ),
          ),
          if (widget.initial != null) ...[
            divider,
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.pop(context, (null,)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15),
                ),
                child: const Text('stop repeating'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.repeat,
                  size: 18,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'When this task is done, creates the next one: '
                    '${repeatSummary(_value, now)} at $time.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickUntil() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _until ?? widget.due,
      firstDate: dateOnly(widget.due),
      lastDate: DateTime(widget.due.year + 10),
    );
    if (d != null) {
      setState(() {
        _until = d;
        _ends = _Ends.on;
      });
    }
  }

  Widget _endsRow(_Ends value, List<Widget> children) => InkWell(
    onTap: () => setState(() => _ends = value),
    child: SizedBox(
      height: 52,
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 15, color: AppColors.foreground),
        child: Row(
          children: [
            // The whole row is the tap target, so the radio needs no padding.
            Radio<_Ends>(
              value: value,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            ...children,
          ],
        ),
      ),
    ),
  );

  Widget _weekdayChip(int d) {
    final selected = _weekdays.contains(d);
    return Semantics(
      button: true,
      selected: selected,
      label: weekdayShort[d - 1],
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => setState(() {
          if (!_weekdays.add(d)) _weekdays.remove(d);
        }),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.primary : AppColors.secondary,
          ),
          child: Text(
            'MTWTFSS'[d - 1],
            style: TextStyle(
              fontSize: 15,
              color: selected ? Colors.white : AppColors.secondaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}

final _fieldBox = BoxDecoration(
  border: Border.all(color: AppColors.border),
  borderRadius: BorderRadius.circular(6),
);

/// A 1–999 number field, H1 style.
class _NumberBox extends StatelessWidget {
  const _NumberBox(this.controller, {required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 40,
    child: TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    ),
  );
}
