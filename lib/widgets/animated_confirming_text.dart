import 'package:flutter/material.dart';

class AnimatedConfirmingText extends StatefulWidget {
  final double fontSize;
  final FontWeight fontWeight;
  
  const AnimatedConfirmingText({
    super.key,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w500,
  });

  @override
  AnimatedConfirmingTextState createState() => AnimatedConfirmingTextState();
}

class AnimatedConfirmingTextState extends State<AnimatedConfirmingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final String _text = "Confirming";
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000), // Slightly slower for readability
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
        return RichText(
          text: TextSpan(
            children: _buildAnimatedLetters(),
          ),
        );
      },
    );
  }
  
  List<TextSpan> _buildAnimatedLetters() {
    final animationValue = _animationController.value;
    final letters = _text.split('');
    final totalLetters = letters.length;
    
    return letters.asMap().entries.map((entry) {
      final index = entry.key;
      final letter = entry.value;
      
      // Calculate wave position for this letter
      final letterProgress = (animationValue * totalLetters * 2) - index;
      
      // Create wave effect with smooth transitions
      double opacity;
      if (letterProgress >= 0 && letterProgress <= totalLetters) {
        // Wave is passing through this letter
        final wavePosition = (letterProgress / totalLetters).clamp(0.0, 1.0);
        opacity = 0.3 + (0.7 * (1.0 - (wavePosition - 0.5).abs() * 2).clamp(0.0, 1.0));
      } else {
        // Letter is in dim state
        opacity = 0.3;
      }
      
      return TextSpan(
        text: letter,
        style: TextStyle(
          color: const Color(0xFFFF6B00).withOpacity(opacity),
          fontSize: widget.fontSize,
          fontWeight: widget.fontWeight,
          letterSpacing: 0.5,
        ),
      );
    }).toList();
  }
}