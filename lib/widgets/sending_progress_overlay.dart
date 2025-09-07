import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/formatters.dart';
import 'dart:ui';
import 'dart:async';

class SendingProgressOverlay extends StatefulWidget {
  final String status;
  final double progress;
  final bool isVisible;
  final String eta;
  final String? completedTxid;
  final double? sentAmount;
  final String? toAddress;
  final VoidCallback? onClose;

  const SendingProgressOverlay({
    super.key,
    required this.status,
    required this.progress,
    required this.isVisible,
    this.eta = '',
    this.completedTxid,
    this.sentAmount,
    this.toAddress,
    this.onClose,
  });

  @override
  State<SendingProgressOverlay> createState() => _SendingProgressOverlayState();
}

class _SendingProgressOverlayState extends State<SendingProgressOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _innerRotationController;
  late AnimationController _outerRotationController;
  late AnimationController _pulseController;
  late AnimationController _checkmarkController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _innerRotationAnimation;
  late Animation<double> _outerRotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _checkmarkAnimation;

  // Preserve last visible status so fade-out keeps the same visual state
  String _lastVisibleStatus = '';

  Timer? _autoCloseTimer;
  int _countdownSeconds = 8;

  @override
  void initState() {
    super.initState();

    // Fade in/out controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Inner circle: Slower constant speed (6 seconds per rotation)
    _innerRotationController = AnimationController(
      duration: const Duration(seconds: 6), // Slower ring
      vsync: this,
    );

    // Outer circle: Faster constant speed (4 seconds per rotation)
    _outerRotationController = AnimationController(
      duration: const Duration(seconds: 4), // Faster ring
      vsync: this,
    );

    // Logo pulse: Remove pulsing for static professional look
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1), // Minimal, unused
      vsync: this,
    );

    // Checkmark animation for success state
    _checkmarkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _innerRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_innerRotationController); // No curve - instant constant speed

    _outerRotationAnimation = Tween<double>(
      begin: 0.0,
      end: -1.0, // Negative for counter-clockwise
    ).animate(_outerRotationController); // No curve - instant constant speed

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _checkmarkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _checkmarkController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void didUpdateWidget(SendingProgressOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _fadeController.forward();
      // Start both rotation animations immediately for faster dynamic movement
      _innerRotationController.repeat();
      _outerRotationController.repeat();
      // No pulsing animation for static logo
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _fadeController.reverse();
      // Stop all animations
      _innerRotationController.stop();
      _outerRotationController.stop();
      _pulseController.stop();
      // Do NOT reset checkmark here to preserve success visuals during fade-out
    } else if (widget.status == 'success' && oldWidget.status != 'success') {
      // Transition to success state - stop spinning and show checkmark
      _innerRotationController.stop();
      _outerRotationController.stop();
      _checkmarkController.reset();
      _checkmarkController.forward();
      // Start 3-second countdown timer
      _startAutoCloseCountdown();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _innerRotationController.dispose();
    _outerRotationController.dispose();
    _pulseController.dispose();
    _checkmarkController.dispose();
    _autoCloseTimer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // Debug: Print what values the overlay is receiving
    if (widget.isVisible) {
      print('🎨 PROGRESS OVERLAY: status="${widget.status}", progress=${widget.progress}, eta="${widget.eta}", visible=${widget.isVisible}');
    }

    if (!widget.isVisible && _fadeController.isDismissed) {
      return const SizedBox.shrink();
    }

    // If overlay is visible, remember the last non-empty status to avoid
    // showing fallback text on the final fade-out frame.
    if (widget.isVisible && widget.status.isNotEmpty) {
      _lastVisibleStatus = widget.status;
    }

    // Determine which status to render (preserve last visible one during fade-out)
    final effectiveStatus =
        widget.isVisible ? (widget.status.isNotEmpty ? widget.status : _lastVisibleStatus) : _lastVisibleStatus;

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
                          // Show either spinning rings (during progress) or checkmark (on success)
                          Container(
                            width: 80,
                            height: 80,
                            child: effectiveStatus == 'success'
                                ? _buildSuccessCheckmark()
                                : _buildSpinningRings(),
                          ),

                          const SizedBox(height: 24),

                          // Status text - different content for success vs progress
                          widget.status == 'success'
                              ? _buildSuccessContent()
                              : _buildProgressContent(statusOverride: effectiveStatus.isNotEmpty ? effectiveStatus : 'Processing...'),

                          // Show progress details only when not in success state
                          if (effectiveStatus != 'success') ...[
                            const SizedBox(height: 16),

                            // Progress bar (only show if progress > 0)
                            if (widget.progress > 0) ...[
                              Container(
                                width: 200,
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: widget.progress.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Progress percentage
                              Text(
                                '${(widget.progress * 100).toInt()}%',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // ETA display (if available)
                            if (widget.eta.isNotEmpty) ...[
                              Text(
                                widget.eta,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Subtext
                            // Subtext (keep consistent wording; never revert to "Please wait")
                            Text(
                              'Processing...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),

                            // Add animated dots for loading effect
                            const SizedBox(height: 16),
                            _LoadingDots(),
                          ],
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

  /// Build spinning rings for progress state
  Widget _buildSpinningRings() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer Circle (Counter-clockwise) - Break at 120°
        AnimatedBuilder(
          animation: _outerRotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _outerRotationAnimation.value * 2 * 3.14159,
              child: CustomPaint(
                size: const Size(80, 80),
                painter: SingleBreakCirclePainter(
                  progress: widget.progress,
                  isOuter: true,
                ),
              ),
            );
          },
        ),

        // Inner Circle (Clockwise) - Break at 0° (top)
        AnimatedBuilder(
          animation: _innerRotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _innerRotationAnimation.value * 2 * 3.14159,
              child: CustomPaint(
                size: const Size(65, 65),
                painter: SingleBreakCirclePainter(
                  progress: widget.progress,
                  isOuter: false,
                ),
              ),
            );
          },
        ),

        // Static BitcoinZ Logo with Soft Elegant Glow
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFCC5500).withOpacity(0.4), // Softer deep amber glow
                blurRadius: 20,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: const Color(0xFFFF8F00).withOpacity(0.25), // Softer medium amber
                blurRadius: 35,
                spreadRadius: 8,
              ),
              BoxShadow(
                color: const Color(0xFFFFA000).withOpacity(0.15), // Very soft halo
                blurRadius: 50,
                spreadRadius: 15,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/bitcoinz_logo.png',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  /// Build success checkmark with green circle
  Widget _buildSuccessCheckmark() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Green success circle
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withOpacity(0.2),
            border: Border.all(
              color: Colors.green,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        // Animated checkmark
        AnimatedBuilder(
          animation: _checkmarkAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _checkmarkAnimation.value,
              child: Icon(
                Icons.check,
                color: Colors.green,
                size: 40,
              ),
            );
          },
        ),
      ],
    );
  }

  /// Build progress content (normal status text)
  Widget _buildProgressContent({String? statusOverride}) {
    final text = (statusOverride ?? widget.status).isNotEmpty
        ? (statusOverride ?? widget.status)
        : 'Processing...';
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withOpacity(0.9),
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
    );
  }

  /// Build success content (title, amount, transaction details)
  Widget _buildSuccessContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success title
        Text(
          'Transaction Sent!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 16),

        // Amount sent (if provided)
        if (widget.sentAmount != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.15),
                  Colors.green.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 16,
                ),
                const SizedBox(height: 8),
                Text(
                  'Amount Sent',
                  style: TextStyle(
                    color: Colors.green.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.formatBtczTrim(widget.sentAmount!),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Transaction ID (if provided)
        if (widget.completedTxid != null) ...[
          GestureDetector(
            onTap: () => _copyToClipboard(widget.completedTxid!),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TX ID',
                          style: TextStyle(
                            color: Colors.grey.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.completedTxid!.length > 16
                              ? '${widget.completedTxid!.substring(0, 8)}...${widget.completedTxid!.substring(widget.completedTxid!.length - 8)}'
                              : widget.completedTxid!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.copy,
                    color: Colors.grey.withOpacity(0.6),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.orange.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Text(
            'Confirming',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Close button with countdown
        ElevatedButton(
          onPressed: widget.onClose,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            _countdownSeconds > 0 ? 'Close ($_countdownSeconds)' : 'Close',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Start 8-second countdown timer with auto-close
  void _startAutoCloseCountdown() {
    _autoCloseTimer?.cancel(); // Cancel any existing timer
    _countdownSeconds = 8;

    _autoCloseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _countdownSeconds--;
        });

        if (_countdownSeconds <= 0) {
          timer.cancel();
          // Auto-close the overlay
          if (widget.onClose != null && mounted) {
            widget.onClose!();
          }
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// Copy transaction ID to clipboard
  void _copyToClipboard(String txid) async {
    await Clipboard.setData(ClipboardData(text: txid));

    // Show a brief feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction ID copied to clipboard'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

// Custom painter for elegant single-break rings
class SingleBreakCirclePainter extends CustomPainter {
  final double progress;
  final bool isOuter;

  SingleBreakCirclePainter({required this.progress, required this.isOuter});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2 - 5); // Identical size for both rings

    // Ring properties - identical thickness for both rings
    final strokeWidth = 4.5; // Same thickness for perfect consistency
    final gapAngle = 0.7; // Same larger gap for both rings - ultra-smooth fade-out
    final baseColor = isOuter
        ? const Color(0xFF995500) // Deeper amber for outer
        : const Color(0xFFCC5500); // Medium amber for inner

    // Complementary break positions for visual harmony
    final startAngle = isOuter
        ? -0.785398 // Outer ring: break at 135° (-π/4) for better balance
        : -1.5708;  // Inner ring: break at top (-π/2) as reference
    final arcAngle = (2 * 3.14159) - gapAngle; // Full circle minus gap

    // Main ring with consistent thickness - solid color throughout
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.8)
      ..color = baseColor.withOpacity(0.9); // Solid consistent color

    // Draw the main arc (circle with single break) - consistent thickness
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      arcAngle,
      false,
      mainPaint,
    );

    // Create fade-out effect only at gap endpoints for soft endings
    final gapFadeAngle = 0.3; // Small fade zone at gap ends

    // Left gap fade
    final leftFadePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5);

    final leftGradient = SweepGradient(
      colors: [
        baseColor.withOpacity(0.9),
        baseColor.withOpacity(0.0),
      ],
      stops: [0.0, 1.0],
      startAngle: startAngle + arcAngle - gapFadeAngle,
      endAngle: startAngle + arcAngle,
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    leftFadePaint.shader = leftGradient;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + arcAngle - gapFadeAngle,
      gapFadeAngle,
      false,
      leftFadePaint,
    );

    // Right gap fade
    final rightFadePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5);

    final rightGradient = SweepGradient(
      colors: [
        baseColor.withOpacity(0.0),
        baseColor.withOpacity(0.9),
      ],
      stops: [0.0, 1.0],
      startAngle: startAngle,
      endAngle: startAngle + gapFadeAngle,
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    rightFadePaint.shader = rightGradient;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      gapFadeAngle,
      false,
      rightFadePaint,
    );

    // Enhanced multi-layer glow system for ultra-soft rounded endings

    // Wide outer halo - ultra-soft
    final outerHaloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.5)
      ..color = baseColor.withOpacity(0.08);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      arcAngle,
      false,
      outerHaloPaint,
    );

    // Medium glow layer - enhanced blur
    final mediumGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.2)
      ..color = baseColor.withOpacity(0.12);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      arcAngle,
      false,
      mediumGlowPaint,
    );

    // Soft inner highlight for professional depth
    final innerHighlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.0)
      ..color = const Color(0xFFFF8F00).withOpacity(0.35);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 1),
      startAngle,
      arcAngle,
      false,
      innerHighlightPaint,
    );
  }

  @override
  bool shouldRepaint(SingleBreakCirclePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isOuter != isOuter;
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