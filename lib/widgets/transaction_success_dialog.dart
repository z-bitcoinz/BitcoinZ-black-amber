import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';
import '../utils/formatters.dart';

class TransactionSuccessDialog extends StatefulWidget {
  final String transactionId;
  final double amount;
  final String toAddress;
  final double? fiatAmount;
  final String? currencyCode;
  final double? fee;
  final String? contactName; // Optional friendly recipient name
  final VoidCallback onClose;

  const TransactionSuccessDialog({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.toAddress,
    this.fiatAmount,
    this.currencyCode,
    this.fee,
    this.contactName,
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
            // Only call onClose, let parent handle navigation
            widget.onClose();
          }
        });
      }
    });
    
    // Auto close after 15 seconds (backup timer)
    _autoCloseTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        // Only call onClose, let parent handle navigation
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
                  constraints: BoxConstraints(
                    maxWidth: 400,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(18), // Reduced from 24
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
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                            // Clean Animated Checkmark
                            AnimatedBuilder(
                              animation: _scaleAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _scaleAnimation.value,
                                  child: Container(
                                    width: 60, // Reduced from 80
                                    height: 60, // Reduced from 80
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.green.shade400,
                                        width: 2.5, // Reduced from 3
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.3),
                                          blurRadius: 15, // Reduced from 20
                                          spreadRadius: 3, // Reduced from 5
                                        ),
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.1),
                                          blurRadius: 25, // Reduced from 40
                                          spreadRadius: 8, // Reduced from 15
                                        ),
                                      ],
                                    ),
                                    child: AnimatedBuilder(
                                      animation: _checkAnimation,
                                      builder: (context, child) {
                                        return CustomPaint(
                                          painter: ElegantCheckmarkPainter(
                                            progress: _checkAnimation.value,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            const SizedBox(height: 12), // Reduced from 16
                            
                            // Success title
                            Text(
                              widget.contactName != null && widget.contactName!.isNotEmpty
                                  ? 'Sent to ${widget.contactName!}!'
                                  : 'Transaction Sent!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),

                            const SizedBox(height: 12), // Reduced from 16
                            
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
                                    Formatters.formatBtczTrim(widget.amount),
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
                            
                            const SizedBox(height: 12),
                            
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
                                  // Recipient (show name if available)
                                  if (widget.contactName != null && widget.contactName!.isNotEmpty) ...[
                                    _buildDetailRow(
                                      icon: Icons.person_outline,
                                      label: 'RECIPIENT',
                                      value: widget.contactName!,
                                      onCopy: null,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildDivider(),
                                    const SizedBox(height: 6),
                                  ],
                                  _buildDetailRow(
                                    icon: Icons.account_balance_wallet_outlined,
                                    label: widget.contactName != null && widget.contactName!.isNotEmpty ? 'ADDRESS' : 'TO',
                                    value: _formatAddress(widget.toAddress),
                                    onCopy: () => _copyToClipboard(widget.toAddress, 'Address'),
                                  ),

                                  const SizedBox(height: 6), // Reduced from 8
                                  _buildDivider(),
                                  const SizedBox(height: 6), // Reduced from 8
                                  
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
                                      value: Formatters.formatBtczTrim(widget.fee!),
                                      onCopy: null,
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 6), // Reduced from 8
                                  _buildDivider(),
                                  const SizedBox(height: 6), // Reduced from 8
                                  
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
                                              'Confirming',
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
                            
                            const SizedBox(height: 12), // Reduced from 16
                            
                            // Close button
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8), // Sharp corners
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF1A1A1A), // Deeper dark color
                                    const Color(0xFF0F0F0F), // Even deeper
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8), // Sharp corners
                                  onTap: () {
                                    // Only call onClose, let parent handle navigation
                                    widget.onClose();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: const Text(
                                      'Close',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700, // Sharper font weight
                                        letterSpacing: 1.0, // More spacing
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 6), // Reduced from 8
                            
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Reduced vertical padding
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16, // Reduced from 18
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(width: 8), // Reduced from 10
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10, // Reduced from 11
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12, // Reduced from 13
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 6), // Reduced from 8
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4), // Reduced from 6
              ),
              child: IconButton(
                icon: Icon(
                  Icons.copy,
                  size: 14, // Reduced from 16
                  color: Colors.white.withOpacity(0.7),
                ),
                padding: const EdgeInsets.all(6), // Reduced from 8
                constraints: const BoxConstraints(
                  minWidth: 28, // Reduced from 32
                  minHeight: 28, // Reduced from 32
                ),
                onPressed: onCopy,
              ),
            ),
          ],
        ],
      ),
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

// Elegant checkmark painter with smooth drawing animation
class ElegantCheckmarkPainter extends CustomPainter {
  final double progress;
  
  ElegantCheckmarkPainter({required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.shade500
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // Only draw if we have progress
    if (progress > 0) {
      // First line of checkmark (down-left to center)
      final firstLineProgress = math.min(progress * 1.8, 1.0);
      if (firstLineProgress > 0) {
        final startX = centerX - 14;
        final startY = centerY - 2;
        final midX = centerX - 6;
        final midY = centerY + 8;
        
        path.moveTo(startX, startY);
        path.lineTo(
          startX + ((midX - startX) * firstLineProgress),
          startY + ((midY - startY) * firstLineProgress),
        );
      }
      
      // Second line of checkmark (center to up-right)
      if (progress > 0.4) {
        final secondLineProgress = math.min((progress - 0.4) * 1.8, 1.0);
        final midX = centerX - 6;
        final midY = centerY + 8;
        final endX = centerX + 16;
        final endY = centerY - 10;
        
        // Continue from where first line ended
        if (firstLineProgress >= 1.0) {
          path.lineTo(
            midX + ((endX - midX) * secondLineProgress),
            midY + ((endY - midY) * secondLineProgress),
          );
        }
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Add subtle glow effect when complete
    if (progress > 0.8) {
      final glowPaint = Paint()
        ..color = Colors.green.withOpacity(0.3)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      canvas.drawPath(path, glowPaint);
    }
  }
  
  @override
  bool shouldRepaint(ElegantCheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
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