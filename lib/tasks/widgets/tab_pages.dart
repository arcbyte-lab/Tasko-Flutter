import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models.dart';

/// One page per tab: the list follows the finger and settles on the next or
/// previous tab, as in Santian. A page reports itself through
/// [onPageChanged]; a tab chosen elsewhere (a tap on the tab bar) animates
/// the pages to it. [header] is built above the pages with the live page
/// position (1.4 is 40% of the way from tab 1 to tab 2), so the tab bar's
/// indicator can move with the finger.
class TabPages extends StatefulWidget {
  const TabPages({
    super.key,
    required this.tabs,
    required this.active,
    required this.onPageChanged,
    required this.pageBuilder,
    required this.header,
  });

  final List<TaskTab> tabs;
  final TaskTab active;
  final ValueChanged<TaskTab> onPageChanged;
  final Widget Function(TaskTab tab) pageBuilder;
  final Widget Function(ValueListenable<double> position) header;

  @override
  State<TabPages> createState() => _TabPagesState();
}

class _TabPagesState extends State<TabPages> {
  late final PageController _controller = PageController(
    initialPage: _index,
  )..addListener(() => _position.value = _controller.page ?? _index.toDouble());
  late final _position = ValueNotifier<double>(_index.toDouble());

  /// True while animating to a tapped tab, so the pages passed on the way
  /// don't each become active.
  bool _animating = false;

  int get _index => widget.tabs.indexOf(widget.active);

  @override
  void didUpdateWidget(TabPages old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _followActiveTab();
  }

  void _followActiveTab() {
    if (!_controller.hasClients || _animating) return;
    final target = _index;
    if (_controller.page?.round() == target) return;
    _animating = true;
    _controller
        .animateToPage(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          _animating = false;
          // A different tab may have been picked while this one animated.
          if (mounted) _followActiveTab();
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      widget.header(_position),
      Expanded(
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.tabs.length,
          onPageChanged: (i) {
            if (!_animating) widget.onPageChanged(widget.tabs[i]);
          },
          itemBuilder: (_, i) => widget.pageBuilder(widget.tabs[i]),
        ),
      ),
    ],
  );
}
