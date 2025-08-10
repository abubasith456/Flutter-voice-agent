import 'dart:async';
import 'dart:math' as math;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

import '../models/user.dart';
import '../state/level_bus.dart';
import '../services/livekit_service.dart';

enum AssistantPosition { bottomRight, bottomLeft, topLeft, topRight }

enum TalkMode { holdToTalk, toggle }

class VoiceAssistantFAB extends StatefulWidget {
  final AssistantPosition position;
  final AppUser selectedUser;
  final ValueChanged<bool> onMicToggled;
  final TalkMode mode;
  final double size;

  const VoiceAssistantFAB({
    super.key,
    required this.position,
    required this.onMicToggled,
    required this.selectedUser,
    this.mode = TalkMode.toggle,
    this.size = 64,
  });

  @override
  State<VoiceAssistantFAB> createState() => _VoiceAssistantFABState();
}

class _VoiceAssistantFABState extends State<VoiceAssistantFAB>
    with SingleTickerProviderStateMixin {
  lk.Room? _room;
  bool _active = false;
  bool _connecting = false;
  Timer? _levelTimer;
  double _currentLevel = 0;
  late final AnimationController _pulseController;
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.95,
      upperBound: 1.05,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    _pulseController.dispose();
    _disconnect();
    super.dispose();
  }

  Future<void> _ensureMicrophonePermission() async {
    if (kIsWeb) return; // Browser handles prompt
    var status = await Permission.microphone.status;
    if (status.isGranted) return;
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
      throw Exception('Microphone permission $status. Please enable it in Settings and try again.');
    }
    status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (status.isPermanentlyDenied || status.isRestricted) {
        await openAppSettings();
      }
      throw Exception('Microphone permission $status');
    }
  }

  String _randomString(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return Iterable.generate(len, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String> _fetchToken() async {
    final svc = LiveKitService();
    // Randomize identity, display name, and room for each connection
    final tokenIdentity = 'user_${_randomString(6)}';
    final tokenName = 'Guest ${_randomString(4)}';
    final roomName = 'room_${_randomString(6)}';
    return svc.generateToken(
      tokenIdentity: tokenIdentity,
      tokenName: tokenName,
      roomName: roomName,
      metadataUserId: widget.selectedUser.id,
      metadataUserName: widget.selectedUser.name,
    );
  }

  void _attachRoomListeners(lk.Room room) {
    // Route audio to speaker on mobile platforms
    try {
      lk.Hardware.instance.setSpeakerphoneOn(true);
    } catch (_) {}

    final listener = room.createListener();
    listener.on<lk.RoomEventTrackSubscribed>((event) {
      final track = event.track;
      if (track is lk.RemoteAudioTrack) {
        try {
          track.setPlaybackEnabled(true);
        } catch (_) {}
      }
    });
  }

  Future<void> _connect() async {
    if (_active || _connecting) return;
    setState(() => _connecting = true);
    try {
      await _ensureMicrophonePermission();
      final url = dotenv.env['LIVEKIT_URL'];
      if (url == null || url.isEmpty) {
        throw Exception('LIVEKIT_URL not configured');
      }
      final token = await _fetchToken();

      final room = lk.Room(
        roomOptions: const lk.RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      await room.connect(url, token);
      _attachRoomListeners(room);

      final participant = room.localParticipant;
      if (participant == null) {
        throw Exception('Local participant not available');
      }

      // Enable microphone via LiveKit API to create/publish the local track
      await participant.setMicrophoneEnabled(true);

      try {
        participant.setAttributes({
          'userId': widget.selectedUser.id,
          'userName': widget.selectedUser.name,
        });
      } catch (_) {}

      _room = room;
      _startLevelUpdates();
      setState(() {
        _active = true;
      });
      widget.onMicToggled(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connect failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _startLevelUpdates() {
    _levelTimer?.cancel();
    _phase = 0;
    _levelTimer = Timer.periodic(const Duration(milliseconds: 66), (_) async {
      _phase += 0.3;
      final level = (0.5 + 0.5 * math.sin(_phase)).clamp(0.0, 1.0);
      setState(() => _currentLevel = level);
      VolumeLevelBus.level.value = level;
    });
  }

  Future<void> _disconnect() async {
    _levelTimer?.cancel();
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(false);
      await _room?.disconnect();
      await _room?.dispose();
    } catch (_) {}
    _room = null;
    if (mounted) {
      setState(() {
        _active = false;
        _currentLevel = 0;
      });
      VolumeLevelBus.level.value = 0;
      widget.onMicToggled(false);
    }
  }

  Future<void> _toggle() async {
    if (_active) {
      await _disconnect();
    } else {
      await _connect();
    }
  }

  Alignment _alignmentForPosition() {
    switch (widget.position) {
      case AssistantPosition.bottomRight:
        return Alignment.bottomRight;
      case AssistantPosition.bottomLeft:
        return Alignment.bottomLeft;
      case AssistantPosition.topLeft:
        return Alignment.topLeft;
      case AssistantPosition.topRight:
        return Alignment.topRight;
    }
  }

  EdgeInsets _paddingForPosition() {
    const inset = EdgeInsets.all(16);
    switch (widget.position) {
      case AssistantPosition.bottomRight:
        return inset;
      case AssistantPosition.bottomLeft:
        return const EdgeInsets.only(left: 16, bottom: 16, top: 16, right: 16);
      case AssistantPosition.topLeft:
        return const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 16);
      case AssistantPosition.topRight:
        return const EdgeInsets.only(right: 16, top: 16, left: 16, bottom: 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ScaleTransition(
      scale: _active ? _pulseController : const AlwaysStoppedAnimation(1.0),
      child: FloatingActionButton.extended(
        heroTag: 'voice_assistant_fab',
        onPressed: widget.mode == TalkMode.toggle ? _toggle : null,
        backgroundColor: _active ? Colors.green : Theme.of(context).colorScheme.primary,
        icon: Stack(
          alignment: Alignment.center,
          children: [
            Icon(_active ? Icons.mic : Icons.mic_none),
            if (_connecting)
              const Positioned.fill(
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white70)),
              ),
          ],
        ),
        label: Text(_active ? 'Listening' : 'Voice Assistant'),
      ),
    );

    Widget maybeHoldWrapper = child;
    if (widget.mode == TalkMode.holdToTalk) {
      maybeHoldWrapper = GestureDetector(
        onLongPressStart: (_) => _connect(),
        onLongPressEnd: (_) => _disconnect(),
        child: child,
      );
    }

    return Align(
      alignment: _alignmentForPosition(),
      child: Padding(
        padding: _paddingForPosition(),
        child: maybeHoldWrapper,
      ),
    );
  }
}