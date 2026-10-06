import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Full-screen, video-like background: photos slowly zoom/pan (Ken Burns),
/// sit behind a soft blur, and cross-fade into each other.
class BlurSlideshow extends StatefulWidget {
  final List<String> images;
  final Duration hold;       // how long each photo stays
  final Duration fade;       // cross-fade length
  final double blur;         // blur sigma
  final double darken;       // 0..1 black overlay so text stays readable

  const BlurSlideshow({
    super.key,
    required this.images,
    this.hold = const Duration(seconds: 6),
    this.fade = const Duration(milliseconds: 1400),
    this.blur = 5,
    this.darken = 0.55,
  });

  @override
  State<BlurSlideshow> createState() => _BlurSlideshowState();
}

class _BlurSlideshowState extends State<BlurSlideshow> {
  int _index = 0;
  Timer? _timer;

  // Different drift for each slide so it never feels repetitive.
  static const _drifts = <Alignment>[
    Alignment(-0.6, -0.4),
    Alignment(0.6, -0.2),
    Alignment(-0.3, 0.5),
    Alignment(0.5, 0.4),
    Alignment(0.0, -0.6),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.hold, (_) {
      if (mounted) setState(() => _index = (_index + 1) % widget.images.length);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Warm the cache so the first cross-fade doesn't stutter.
    for (final path in widget.images) {
      precacheImage(AssetImage(path), context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.hold + widget.fade;
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Colors.black),

      AnimatedSwitcher(
        duration: widget.fade,
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: _Slide(
          key: ValueKey(_index),
          path: widget.images[_index],
          drift: _drifts[_index % _drifts.length],
          duration: total,
        ),
      ),

      // Soft blur over the moving photo.
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
        child: const SizedBox.expand(),
      ),

      // Darken + vignette for legibility.
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(widget.darken * 0.9),
              Colors.black.withOpacity(widget.darken * 0.6),
              Colors.black.withOpacity(widget.darken * 1.15),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _Slide extends StatelessWidget {
  final String path;
  final Alignment drift;
  final Duration duration;
  const _Slide({super.key, required this.path, required this.drift, required this.duration});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.linear,
      builder: (_, t, child) => Transform.scale(
        scale: 1.08 + 0.14 * t,          // slow push-in
        alignment: drift,
        child: child,
      ),
      child: SizedBox.expand(
        child: Image.asset(path, fit: BoxFit.cover, alignment: Alignment.topCenter),
      ),
    );
  }
}
