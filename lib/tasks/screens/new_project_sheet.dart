import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models.dart';
import '../task_rules.dart';
import '../tasks_api.dart';
import '../widgets/pickers.dart';
import 'create_task_sheet.dart';

/// Opens the new-project sheet (arcbyte decision 0010). [divisions] are the
/// ones the viewer may create in; the chip to pick one shows only when there
/// is a choice. Resolves to the new project's tab, or null when dismissed.
Future<TaskTab?> showNewProjectSheet(
  BuildContext context, {
  required TasksApi api,
  required List<TaskTab> divisions,
  required DateTime today,
}) => showModalBottomSheet<TaskTab>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: AppColors.background,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
  ),
  builder: (_) => NewProjectForm(api: api, divisions: divisions, today: today),
);

/// Name, division, due date, and "done". A refused create surfaces as the
/// app-wide error toast; the form stays open to try again.
class NewProjectForm extends StatefulWidget {
  const NewProjectForm({
    super.key,
    required this.api,
    required this.divisions,
    required this.today,
  });

  final TasksApi api;
  final List<TaskTab> divisions;
  final DateTime today;

  @override
  State<NewProjectForm> createState() => _NewProjectFormState();
}

class _NewProjectFormState extends State<NewProjectForm> {
  var _name = '';
  late var _division = widget.divisions.first;
  DateTime? _due;
  var _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final tab = await widget.api.createProject(
        _division.id,
        _name.trim(),
        dueDate: _due,
      );
      if (mounted) Navigator.pop(context, tab);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _name = v),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
            decoration: const InputDecoration.collapsed(
              hintText: 'new project',
              hintStyle: TextStyle(color: AppColors.placeholder),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.divisions.length > 1)
                PopupMenuButton<TaskTab>(
                  tooltip: 'Division',
                  position: PopupMenuPosition.under,
                  onSelected: (d) => setState(() => _division = d),
                  itemBuilder: (_) => [
                    for (final d in widget.divisions)
                      PopupMenuItem(value: d, child: Text(d.name)),
                  ],
                  // The menu button handles the tap.
                  child: IgnorePointer(
                    child: SheetChip(
                      icon: Icons.workspaces_outline,
                      label: _division.name,
                      onTap: () {},
                    ),
                  ),
                ),
              SheetChip(
                icon: Icons.calendar_today_outlined,
                label: _due == null
                    ? 'due date'
                    : shortDate(_due!, widget.today),
                onTap: () async {
                  final v = await showPicker<DateTime>(
                    context,
                    DueDatePicker(initial: _due, today: widget.today),
                  );
                  if (v != null) setState(() => _due = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _name.trim().isEmpty || _saving ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('done'),
            ),
          ),
        ],
      ),
    ),
  );
}
