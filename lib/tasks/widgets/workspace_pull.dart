import 'package:flutter/material.dart';

/// Home over My Workspace (hifi H13). Pulling down on the calendar slides
/// home off the bottom; a white strip with a grabber stays behind, and a pull
/// up on it, or a tap, brings home back. The canvas cannot show motion, so
/// this is the only place the animation is written down.
class WorkspacePull extends StatefulWidget {
  const WorkspacePull({
    super.key,
    required this.header,
    required this.open,
    required this.onChanged,
    required this.workspace,
    required this.home,
  });

  /// Height of the strip left behind, with the grabber.
  static const peek = 56.0;

  /// The top bar and the strip, drawn once and never moved; [t] is the pull,
  /// 0 on home and 1 on My Workspace.
  final Widget Function(double t) header;

  final bool open;
  final ValueChanged<bool> onChanged;

  /// My Workspace below the header; it sits under home until a pull starts.
  final Widget workspace;

  /// Home below the header: the calendar and what is under it slide down and
  /// uncover [workspace]. [pull] wraps the part that can be dragged.
  final Widget Function(Widget Function(Widget child) pull) home;

  @override
  State<WorkspacePull> createState() => _WorkspacePullState();
}

class _WorkspacePullState extends State<WorkspacePull>
    with SingleTickerProviderStateMixin {
  late final _t = AnimationController(
    vsync: this,
    value: widget.open ? 1 : 0,
    duration: const Duration(milliseconds: 280),
  );
  double _height = 800;

  @override
  void didUpdateWidget(WorkspacePull old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open) _settle(widget.open);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _settle(bool open) =>
      _t.animateTo(open ? 1 : 0, curve: Curves.easeOutCubic);

  void _drag(DragUpdateDetails d) =>
      _t.value = (_t.value + d.delta.dy / _height).clamp(0.0, 1.0);

  /// Let go past half way, or flick, and it finishes; otherwise it goes back.
  void _end(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final open = v.abs() > 700 ? v > 0 : _t.value > 0.5;
    _settle(open);
    if (open != widget.open) widget.onChanged(open);
  }

  // Raw pointer events, not a drag recognizer: the month sits in a scroll
  // view that would win the gesture. A pull counts once it is mostly
  // downward and has moved a little.
  Offset _moved = Offset.zero;
  bool _pulling = false;

  Widget _pull(Widget child) => Listener(
    onPointerDown: (_) {
      _moved = Offset.zero;
      _pulling = false;
    },
    onPointerMove: (e) {
      _moved += e.delta;
      if (!_pulling &&
          _moved.dy > 12 &&
          _moved.dy > _moved.dx.abs() * 2 &&
          !widget.open) {
        _pulling = true;
        _t.stop();
      }
      if (_pulling) {
        _t.value = (_t.value + e.delta.dy / _height).clamp(0.0, 1.0);
      }
    },
    onPointerUp: (_) => _letGo(),
    onPointerCancel: (_) => _letGo(),
    child: child,
  );

  void _letGo() {
    if (!_pulling) return;
    _pulling = false;
    final open = _t.value > 0.3;
    _settle(open);
    if (open != widget.open) widget.onChanged(open);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black,
    child: Column(
      children: [
        AnimatedBuilder(
          animation: _t,
          builder: (context, _) => widget.header(_t.value),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              _height = box.maxHeight;
              return AnimatedBuilder(
                animation: _t,
                builder: (context, _) => _body(_t.value),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _body(double t) => Stack(
    children: [
      // Built only once a pull starts, so home alone is what shows.
      if (t > 0) Positioned.fill(child: widget.workspace),
      // The strip rises as home leaves.
      if (t > 0)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: WorkspacePull.peek,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * WorkspacePull.peek),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onChanged(false),
              onVerticalDragUpdate: _drag,
              onVerticalDragEnd: _end,
              child: Semantics(
                label: 'swipe up to back to home',
                button: true,
                child: ColoredBox(
                  color: Colors.white,
                  child: Align(
                    alignment: const Alignment(0, -0.4),
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      Positioned.fill(
        child: Transform.translate(
          offset: Offset(0, t * _height),
          child: Offstage(offstage: t >= 1, child: widget.home(_pull)),
        ),
      ),
    ],
  );
}
