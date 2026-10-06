import 'package:flutter/material.dart';

/// Fades + slides a child up into place. Give each list item a growing
/// [index] and they cascade in one after another.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;
  final Duration duration;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDelay = const Duration(milliseconds: 55),
    this.duration = const Duration(milliseconds: 480),
    this.offsetY = 28,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fade = curved;
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(curved);

    // Cap the stagger so long lists don't make the bottom items wait forever.
    final steps = widget.index > 8 ? 8 : widget.index;
    Future.delayed(widget.baseDelay * steps, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

/// Gentle press-down "squish" for any tappable card. Does not consume taps —
/// the child keeps its own onTap/onPressed.
class PressScale extends StatefulWidget {
  final Widget child;
  final double scale;
  const PressScale({super.key, required this.child, this.scale = 0.97});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down ? widget.scale : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// Counts a number up from 0 — for stat tiles.
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text('${v.round()}', style: style),
      );
}

/// Page route with a soft fade + rise, usable in place of MaterialPageRoute.
class FadeRiseRoute<T> extends PageRouteBuilder<T> {
  FadeRiseRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (ctx, _, __) => builder(ctx),
          transitionsBuilder: (_, anim, __, child) {
            final curved =
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
