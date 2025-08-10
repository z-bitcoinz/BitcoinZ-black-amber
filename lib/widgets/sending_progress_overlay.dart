import 'package:flutter/material.dart';
import 'dart:ui';

class SendingProgressOverlay extends StatefulWidget {
  final String status;
  final double progress;
  final bool isVisible;
  
  const SendingProgressOverlay({
    super.key,
    required this.status,
    required this.progress,
    required this.isVisible,
  });

  @override
  State<SendingProgressOverlay> createState() => _SendingProgressOverlayState();
}

class _SendingProgressOverlayState extends State<SendingProgressOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(SendingProgressOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _fadeController.forward();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _fadeController.reverse();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible && _fadeController.isDismissed) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: Colors.black.withOpacity(0.7 * _fadeAnimation.value),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 5 * _fadeAnimation.value,
                  sigmaY: 5 * _fadeAnimation.value,
                ),
                child: Center(
                  child: ScaleTransition(
                    scale: _fadeAnimation,
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2A2A2A).withOpacity(0.95),
                            const Color(0xFF1F1F1F).withOpacity(0.9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress Circle
                          Container(
                            width: 80,
                            height: 80,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Background circle
                                CircularProgressIndicator(
                                  strokeWidth: 6,
                                  value: null,
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                // Progress circle
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 4,
                                    value: widget.progress,
                                    backgroundColor: Colors.white.withOpacity(0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                // Percentage text
                                Text(
                                  '${(widget.progress * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Status text
                          Text(
                            widget.status,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Subtext
                          Text(
                            'Please wait...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          
                          // Add animated dots for loading effect
                          const SizedBox(height: 16),
                          _LoadingDots(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: 0.0,
      end: 3.0,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final int activeDot = _animation.value.floor();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == activeDot
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white.withOpacity(0.3),
              ),
            );
          }),
        );
      },
    );
  }
}