import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedProgressDots extends StatefulWidget {
  const AnimatedProgressDots({super.key});

  @override
  AnimatedProgressDotsState createState() => AnimatedProgressDotsState();
}

class AnimatedProgressDotsState extends State<AnimatedProgressDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animationController.repeat();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final animationValue = _animationController.value;
        
        // Simple sequential dots animation
        final activeIndex = (animationValue * 3).floor() % 3;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(activeIndex == 0 ? 1.0 : 0.3),
            const SizedBox(width: 3),
            _buildDot(activeIndex == 1 ? 1.0 : 0.3),
            const SizedBox(width: 3),
            _buildDot(activeIndex == 2 ? 1.0 : 0.3),
          ],
        );
      },
    );
  }
  
  Widget _buildDot(double opacity) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B00).withOpacity(opacity),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B00).withOpacity(opacity * 0.5),
            blurRadius: 2,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }
}