import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:livekit_voice_assistant/plugin/livekit_theme.dart';
import '../models/user.dart';

class MainScreen extends StatefulWidget {
  static const routeName = '/main';
  final AppUser selectedUser;
  const MainScreen({super.key, required this.selectedUser});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  bool micActive = false;
  Offset _assistantPosition = const Offset(0, 0);

  @override
  Widget build(BuildContext context) {
    final lkUrl = dotenv.env['LIVEKIT_URL'] ?? '';
    return Scaffold(
      body: Stack(
        children: [
          const _AnimatedBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connected Agent',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      shadows: const [
                        Shadow(blurRadius: 6, color: Colors.black87)
                      ],
                    ),
                  ),
                  Text(
                    lkUrl.isEmpty ? 'LIVEKIT_URL not set' : lkUrl,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      shadows: const [
                        Shadow(blurRadius: 6, color: Colors.black87)
                      ],
                    ),
                  ),
                  // --- Show OTP ---
                  if (widget.selectedUser.otp != "")
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use this OTP or Secret for test purpose: ${widget.selectedUser.otp}',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(blurRadius: 6, color: Colors.black87)
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Note: Please wait for the assistance to start, we are running on CPU so it may take some time to replay or start.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                              shadows: const [
                                Shadow(blurRadius: 6, color: Colors.black87)
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: micActive
                          ? Column(
                              key: const ValueKey('connected'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mic,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Listening...',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w300,
                                      ),
                                ),
                              ],
                            )
                          : Text(
                              'Tap the assistant to start',
                              key: const ValueKey('hint'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w300,
                                  ),
                            ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          // Replace VoiceAssistantFAB with AIVoiceAssistantWidget
          LiveKitVoiceAssistant(
            url: lkUrl,
            selectedUser: widget.selectedUser,
            theme: VoiceAssistantTheme.dark,
            width: 240,
            height: 60,
            position: AssistantPosition.bottomRight,
            onPositionChanged: (newPosition) {
              setState(() {
                _assistantPosition = newPosition;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _AnimatedBackground extends StatefulWidget {
  const _AnimatedBackground();

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                    Colors.indigo.shade900, Colors.deepPurple.shade700, t)!,
                Color.lerp(
                    Colors.blue.shade700, Colors.indigo.shade500, 1 - t)!,
              ],
            ),
          ),
          child: CustomPaint(
            painter: _WavesPainter(progress: t),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _WavesPainter extends CustomPainter {
  final double progress;
  _WavesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.1);

    final centerY = size.height * 0.65;
    final amplitude = 12.0 + 8.0 * (progress - 0.5).abs();

    for (double i = 0; i < size.width; i += 8) {
      final y = centerY +
          amplitude * (1.5 * (i / size.width * 6.283 + progress * 6.283));
      final sinY = centerY + amplitude * math.sin(y);
      canvas.drawCircle(Offset(i, sinY), 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
