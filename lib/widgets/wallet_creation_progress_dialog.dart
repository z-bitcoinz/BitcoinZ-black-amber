import 'package:flutter/material.dart';
import 'dart:math' as math;

class WalletCreationProgressDialog extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() onCreateWallet;
  final void Function(Map<String, dynamic>)? onSuccess;
  final void Function(String)? onError;

  const WalletCreationProgressDialog({
    super.key,
    required this.onCreateWallet,
    this.onSuccess,
    this.onError,
  });

  @override
  State<WalletCreationProgressDialog> createState() => _WalletCreationProgressDialogState();
}

class _WalletCreationProgressDialogState extends State<WalletCreationProgressDialog>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _particleAnimation;

  int _currentStep = 0;
  double _progress = 0.0;
  bool _isComplete = false;
  String? _error;

  final List<ProgressStep> _steps = [
    ProgressStep(
      title: 'Generating cryptographic keys...',
      description: 'Creating secure private keys',
      icon: Icons.vpn_key,
      duration: Duration(milliseconds: 1200),
    ),
    ProgressStep(
      title: 'Creating secure seed phrase...',
      description: 'Generating 24-word recovery phrase',
      icon: Icons.security,
      duration: Duration(milliseconds: 1000),
    ),
    ProgressStep(
      title: 'Initializing wallet structure...',
      description: 'Setting up wallet database',
      icon: Icons.account_balance_wallet,
      duration: Duration(milliseconds: 800),
    ),
    ProgressStep(
      title: 'Finalizing wallet...',
      description: 'Completing setup process',
      icon: Icons.check_circle_outline,
      duration: Duration(milliseconds: 600),
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 3800), // Total duration
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.linear,
    ));

    _pulseController.repeat(reverse: true);
    _particleController.repeat();
    
    _startWalletCreation();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _startWalletCreation() async {
    try {
      // Start progress animation
      _progressController.forward();
      
      // Simulate realistic wallet creation timing
      for (int i = 0; i < _steps.length; i++) {
        if (mounted) {
          setState(() {
            _currentStep = i;
            _progress = (i / _steps.length);
          });
          
          await Future.delayed(_steps[i].duration);
        }
      }
      
      // Actually create the wallet
      final walletData = await widget.onCreateWallet();
      
      // Complete progress
      if (mounted) {
        setState(() {
          _currentStep = _steps.length - 1;
          _progress = 1.0;
          _isComplete = true;
        });
        
        // Wait for completion animation
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (widget.onSuccess != null) {
          widget.onSuccess!(walletData);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
        
        if (widget.onError != null) {
          widget.onError!(e.toString());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              'Creating Your Wallet',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Setting up your secure BitcoinZ wallet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            
            // Progress Ring and Particles
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background particles
                  AnimatedBuilder(
                    animation: _particleAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(200, 200),
                        painter: ParticlePainter(_particleAnimation.value),
                      );
                    },
                  ),
                  
                  // Progress ring
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(160, 160),
                        painter: ProgressRingPainter(_progressAnimation.value),
                      );
                    },
                  ),
                  
                  // Center content
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B00), Color(0xFFFFAA00)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B00).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _error != null ? Icons.error_outline :
                            _isComplete ? Icons.check :
                            _currentStep < _steps.length ? _steps[_currentStep].icon :
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Progress percentage
                  Positioned(
                    bottom: -5,
                    child: Text(
                      '${(_progress * 100).round()}%',
                      style: const TextStyle(
                        color: Color(0xFFFF6B00),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Current step info
            if (_error == null) ...[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(_currentStep),
                  children: [
                    Text(
                      _currentStep < _steps.length ? 
                        _steps[_currentStep].title :
                        'Wallet created successfully!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentStep < _steps.length ? 
                        _steps[_currentStep].description :
                        'Your wallet is ready to use',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Step indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (index) {
                  final isCompleted = index < _currentStep || _isComplete;
                  final isCurrent = index == _currentStep && !_isComplete;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent ? 
                        const Color(0xFFFF6B00) :
                        Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ] else ...[
              // Error state
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Wallet Creation Failed',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProgressStep {
  final String title;
  final String description;
  final IconData icon;
  final Duration duration;

  const ProgressStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.duration,
  });
}

class ProgressRingPainter extends CustomPainter {
  final double progress;

  ProgressRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    // Background ring
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Progress ring
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF6B00), Color(0xFFFFAA00)],
        stops: [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is ProgressRingPainter && oldDelegate.progress != progress;
  }
}

class ParticlePainter extends CustomPainter {
  final double animation;

  ParticlePainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = const Color(0xFFFF6B00).withOpacity(0.3);
    
    // Draw floating particles
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi * 2 / 8) + (animation * math.pi * 2);
      final radius = 60 + (math.sin(animation * math.pi * 2 + i) * 20);
      final particleX = center.dx + math.cos(angle) * radius;
      final particleY = center.dy + math.sin(angle) * radius;
      
      canvas.drawCircle(
        Offset(particleX, particleY),
        3 + math.sin(animation * math.pi * 4 + i) * 1,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is ParticlePainter && oldDelegate.animation != animation;
  }
}