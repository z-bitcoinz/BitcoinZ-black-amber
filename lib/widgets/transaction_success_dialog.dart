import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';

class TransactionSuccessDialog extends StatefulWidget {
  final String transactionId;
  final double amount;
  final String toAddress;
  final double? fiatAmount;
  final String? currencyCode;
  final double? fee;
  final VoidCallback onClose;

  const TransactionSuccessDialog({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.toAddress,
    this.fiatAmount,
    this.currencyCode,
    this.fee,
    required this.onClose,
  });

  @override
  State<TransactionSuccessDialog> createState() => _TransactionSuccessDialogState();
}

class _TransactionSuccessDialogState extends State<TransactionSuccessDialog>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late AnimationController _confettiController;
  late Animation<double> _checkAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  
  Timer? _autoCloseTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 15; // Increased from 8 to 15 seconds
  final List<ConfettiParticle> _particles = [];
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _checkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOutBack,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _scaleController.forward().then((_) {
      _checkController.forward();
      _confettiController.forward();
      _pulseController.repeat(reverse: true);
    });
    
    // Generate confetti particles after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateConfetti();
    });
    
    // Start countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            timer.cancel();
            Navigator.of(context).pop();
            widget.onClose();
          }
        });
      }
    });
    
    // Auto close after 15 seconds
    _autoCloseTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onClose();
      }
    });
  }
  
  @override
  void dispose() {
    _checkController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    _confettiController.dispose();
    _autoCloseTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
  
  void _generateConfetti() {
    if (!mounted) return;
    
    final random = math.Random();
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    for (int i = 0; i < 30; i++) { // Reduced from 50 to 30 for subtlety
      _particles.add(ConfettiParticle(
        x: random.nextDouble(),
        y: random.nextDouble() * 0.3,
        velocityX: (random.nextDouble() - 0.5) * 1.5,
        velocityY: random.nextDouble() * 1.5 + 0.5,
        color: [
          primaryColor,
          primaryColor.withOpacity(0.7),
          Colors.green,
          Colors.green.shade300,
        ][random.nextInt(4)],
        size: random.nextDouble() * 3 + 2,
      ));
    }
    
    // Trigger rebuild to show particles
    if (mounted) setState(() {});
  }
  
  String _formatAddress(String address) {
    if (address.length <= 20) return address;
    return '${address.substring(0, 10)}...${address.substring(address.length - 10)}';
  }
  
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: _confettiController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Subtle confetti particles
              ..._particles.map((particle) {
                final progress = _confettiController.value;
                final x = particle.x + particle.velocityX * progress;
                final y = particle.y + particle.velocityY * progress * progress;
                final opacity = math.max(0.0, 0.6 - progress * 0.6);
                
                return Positioned(
                  left: x * MediaQuery.of(context).size.width,
                  top: y * MediaQuery.of(context).size.height,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: progress * particle.velocityX * 10,
                      child: Container(
                        width: particle.size,
                        height: particle.size,
                        decoration: BoxDecoration(
                          color: particle.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              
              // Main dialog content
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF2A2A2A).withOpacity(0.95),
                              const Color(0xFF1F1F1F).withOpacity(0.9),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Animated checkmark with pulse
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green.shade400,
                                          Colors.green.shade600,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.5),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: AnimatedBuilder(
                                      animation: _checkAnimation,
                                      builder: (context, child) {
                                        return CustomPaint(
                                          painter: CheckmarkPainter(
                                            progress: _checkAnimation.value,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Success title
                            const Text(
                              'Transaction Sent!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Amount Card
                            Container(
                              width: double.infinity,
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
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Amount Sent',
                                        style: TextStyle(
                                          color: Colors.green.shade300,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${widget.amount.toStringAsFixed(8)} BTCZ',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  if (widget.fiatAmount != null && widget.currencyCode != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '≈ ${widget.fiatAmount!.toStringAsFixed(2)} ${widget.currencyCode}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Transaction details card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // To address
                                  _buildDetailRow(
                                    icon: Icons.account_balance_wallet_outlined,
                                    label: 'TO',
                                    value: _formatAddress(widget.toAddress),
                                    onCopy: () => _copyToClipboard(widget.toAddress, 'Address'),
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  _buildDivider(),
                                  const SizedBox(height: 12),
                                  
                                  // Transaction ID
                                  _buildDetailRow(
                                    icon: Icons.tag,
                                    label: 'TX ID',
                                    value: '${widget.transactionId.substring(0, 12)}...',
                                    onCopy: () => _copyToClipboard(widget.transactionId, 'Transaction ID'),
                                  ),
                                  
                                  if (widget.fee != null) ...[
                                    const SizedBox(height: 12),
                                    _buildDivider(),
                                    const SizedBox(height: 12),
                                    
                                    // Network fee
                                    _buildDetailRow(
                                      icon: Icons.speed_outlined,
                                      label: 'NETWORK FEE',
                                      value: '${widget.fee!.toStringAsFixed(8)} BTCZ',
                                      onCopy: null,
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 12),
                                  _buildDivider(),
                                  const SizedBox(height: 12),
                                  
                                  // Status
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.circle_notifications,
                                        size: 18,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'STATUS',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.orange.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 8,
                                              height: 8,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Broadcasting',
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Done button
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    widget.onClose();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    child: const Text(
                                      'Done',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Auto-close countdown
                            Text(
                              'Closing in $_remainingSeconds seconds',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.white.withOpacity(0.5),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.copy,
              size: 14,
              color: Colors.white.withOpacity(0.5),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            onPressed: onCopy,
          ),
        ],
      ],
    );
  }
  
  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0),
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0),
          ],
        ),
      ),
    );
  }
}

class ConfettiParticle {
  final double x;
  final double y;
  final double velocityX;
  final double velocityY;
  final Color color;
  final double size;
  
  ConfettiParticle({
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    required this.color,
    required this.size,
  });
}

class CheckmarkPainter extends CustomPainter {
  final double progress;
  
  CheckmarkPainter({required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    if (progress > 0) {
      // Draw checkmark
      final firstLineProgress = math.min(progress * 2, 1.0);
      if (firstLineProgress > 0) {
        path.moveTo(centerX - 12, centerY);
        path.lineTo(
          centerX - 12 + (8 * firstLineProgress),
          centerY + (8 * firstLineProgress),
        );
      }
      
      if (progress > 0.5) {
        final secondLineProgress = (progress - 0.5) * 2;
        path.lineTo(
          centerX - 4 + (16 * secondLineProgress),
          centerY + 8 - (16 * secondLineProgress),
        );
      }
    }
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}