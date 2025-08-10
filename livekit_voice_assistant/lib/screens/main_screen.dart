import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user.dart';
import '../widgets/voice_assistant_fab.dart';
import '../widgets/volume_equalizer.dart';

AssistantPosition _parsePosition(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'bottomleft':
    case 'bottom_left':
      return AssistantPosition.bottomLeft;
    case 'topleft':
    case 'top_left':
      return AssistantPosition.topLeft;
    case 'topright':
    case 'top_right':
      return AssistantPosition.topRight;
    case 'bottomright':
    case 'bottom_right':
    default:
      return AssistantPosition.bottomRight;
  }
}

TalkMode _parseMode(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'hold':
    case 'holdtotalk':
    case 'hold_to_talk':
      return TalkMode.holdToTalk;
    case 'toggle':
    default:
      return TalkMode.toggle;
  }
}

class MainScreen extends StatefulWidget {
  static const routeName = '/main';
  final AppUser selectedUser;
  final String? roomName;
  const MainScreen({super.key, required this.selectedUser, this.roomName});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  bool micActive = false;

  @override
  Widget build(BuildContext context) {
    final lkUrl = dotenv.env['LIVEKIT_URL'] ?? '';
    final position = _parsePosition(dotenv.env['ASSISTANT_POSITION']);
    final mode = _parseMode(dotenv.env['ASSISTANT_MODE']);
    final roomLabel = widget.roomName ?? (dotenv.env['LIVEKIT_ROOM_NAME'] ?? 'voice-assistant-room');
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
                          shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
                        ),
                  ),
                  Text(
                    lkUrl.isEmpty ? 'LIVEKIT_URL not set' : '$lkUrl ($roomLabel)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
                        ),
                  ),
                  const Spacer(),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: micActive
                          ? const VolumeEqualizer(key: ValueKey('equalizer'))
                          : Text(
                              'Tap the assistant to start',
                              key: const ValueKey('hint'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w300),
                            ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          VoiceAssistantFAB(
            position: position,
            onMicToggled: (active) => setState(() => micActive = active),
            selectedUser: widget.selectedUser,
            mode: mode,
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
    controller = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
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
                Color.lerp(Colors.indigo.shade900, Colors.deepPurple.shade700, t)!,
                Color.lerp(Colors.blue.shade700, Colors.indigo.shade500, 1 - t)!,
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
      final y = centerY + amplitude *
          (1.5 * (i / size.width * 6.283 + progress * 6.283));
      final sinY = centerY + amplitude * math.sin(y);
      canvas.drawCircle(Offset(i, sinY), 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter oldDelegate) => oldDelegate.progress != progress;
}