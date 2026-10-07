import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../task_rules.dart';
import 'pickers.dart';

/// "request extension": current due, a new due date, and a required reason.
/// Resolves to (new due, reason), or null when dismissed.
Future<(DateTime, String)?> showExtensionSheet(
  BuildContext context, {
  required DateTime? currentDue,
  required DateTime today,
}) => showPicker<(DateTime, String)>(
  context,
  _ExtensionSheet(currentDue: currentDue, today: today),
);

/// "decline": a required reason. Resolves to it, or null when dismissed.
Future<String?> showDeclineSheet(BuildContext context) =>
    showPicker<String>(context, const _DeclineSheet());

class _ExtensionSheet extends StatefulWidget {
  const _ExtensionSheet({required this.currentDue, required this.today});

  final DateTime? currentDue;
  final DateTime today;

  @override
  State<_ExtensionSheet> createState() => _ExtensionSheetState();
}

class _ExtensionSheetState extends State<_ExtensionSheet> {
  DateTime? _newDue;
  String _reason = '';

  String _date(DateTime? d) => d == null
      ? 'pick a date'
      : '${shortDate(d, widget.today)}, '
            '${formatTime(TimeOfDay.fromDateTime(d))}';

  @override
  Widget build(BuildContext context) {
    final ready = _newDue != null && _reason.trim().isNotEmpty;
    return _ReasonFrame(
      title: 'request extension',
      button: 'send request',
      destructive: false,
      onReason: (v) => setState(() => _reason = v),
      onSubmit: ready
          ? () => Navigator.pop(context, (_newDue!, _reason.trim()))
          : null,
      above: [
        _Row(label: 'current due', value: _date(widget.currentDue)),
        _Row(
          label: 'new due',
          value: _date(_newDue),
          onTap: () async {
            final d = await showPicker<DateTime>(
              context,
              DueDatePicker(
                initial: _newDue ?? widget.currentDue,
                today: widget.today,
              ),
            );
            if (d != null) setState(() => _newDue = d);
          },
        ),
      ],
    );
  }
}

class _DeclineSheet extends StatefulWidget {
  const _DeclineSheet();

  @override
  State<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends State<_DeclineSheet> {
  String _reason = '';

  @override
  Widget build(BuildContext context) => _ReasonFrame(
    title: 'decline',
    button: 'decline',
    destructive: true,
    onReason: (v) => setState(() => _reason = v),
    onSubmit: _reason.trim().isEmpty
        ? null
        : () => Navigator.pop(context, _reason.trim()),
  );
}

/// Title, optional rows, a required "reason" field, then one full-width button.
class _ReasonFrame extends StatelessWidget {
  const _ReasonFrame({
    required this.title,
    required this.button,
    required this.destructive,
    required this.onReason,
    required this.onSubmit,
    this.above = const [],
  });

  final String title;
  final String button;
  final bool destructive;
  final ValueChanged<String> onReason;
  final VoidCallback? onSubmit;
  final List<Widget> above;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppColors.border),
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
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...above,
            const SizedBox(height: 12),
            const Text.rich(
              TextSpan(
                text: 'reason ',
                children: [
                  TextSpan(
                    text: 'required',
                    style: TextStyle(color: AppColors.destructive),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              autofocus: above.isEmpty,
              onChanged: onReason,
              minLines: 3,
              maxLines: 5,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                border: border,
                enabledBorder: border,
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: destructive ? AppColors.destructive : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Text(button),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 44,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: onTap == null ? AppColors.foreground : AppColors.primary,
            ),
          ),
        ],
      ),
    ),
  );
}
