import 'package:flutter/material.dart';
import 'dart:math' as math;

class MeshBackground extends StatefulWidget {
  final Widget child;
  const MeshBackground({super.key, required this.child});

  @override
  State<MeshBackground> createState() => _MeshBackgroundState();
}

class _MeshBackgroundState extends State<MeshBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Use theme background
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              // Градиент 1
              Positioned(
                top: -100 + 50 * math.sin(_controller.value * 2 * math.pi),
                left: -100 + 50 * math.cos(_controller.value * 2 * math.pi),
                child: _Blob(color: theme.colorScheme.primary.withOpacity(0.15), size: 400),
              ),
              // Градиент 2
              Positioned(
                bottom: -100 + 50 * math.cos(_controller.value * 2 * math.pi),
                right: -100 + 50 * math.sin(_controller.value * 2 * math.pi),
                child: _Blob(color: theme.colorScheme.secondary.withOpacity(0.1), size: 500),
              ),
              // Основной контент
              widget.child,
            ],
          );
        },
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}
