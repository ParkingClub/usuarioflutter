import 'package:flutter/material.dart';

class PulsingUserMarker extends StatefulWidget {
  final double size;

  const PulsingUserMarker({super.key, this.size = 60.0});

  @override
  State<PulsingUserMarker> createState() => _PulsingUserMarkerState();
}

class _PulsingUserMarkerState extends State<PulsingUserMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFF920606),
            width: 3.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: widget.size / 3,
            height: widget.size / 3,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF920606),
            ),
          ),
        ),
      ),
    );
  }
}