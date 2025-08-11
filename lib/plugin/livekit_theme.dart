import 'dart:math';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_voice_assistant/models/user.dart';
import 'package:livekit_voice_assistant/services/livekit_service.dart';
import 'package:permission_handler/permission_handler.dart';

enum AssistantPosition {
  bottomRight,
  bottomLeft,
  topLeft,
  topRight,
}

class LiveKitVoiceAssistant extends StatefulWidget {
  final String url;
  final VoiceAssistantTheme theme;
  final AssistantPosition position;
  final Function(Offset)? onPositionChanged;
  final double width;
  final double height;
  final AppUser selectedUser;

  const LiveKitVoiceAssistant({
    super.key,
    required this.url,
    required this.selectedUser,
    this.theme = const VoiceAssistantTheme(),
    this.position = AssistantPosition.bottomRight,
    this.onPositionChanged,
    this.width = 140,
    this.height = 40,
  });

  @override
  State<LiveKitVoiceAssistant> createState() => _LiveKitVoiceAssistantState();
}

class _LiveKitVoiceAssistantState extends State<LiveKitVoiceAssistant>
    with TickerProviderStateMixin {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isConnected = false;
  bool _isMicEnabled = false;
  bool _isConnecting = false;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  Offset _currentPosition = const Offset(0, 0);

  String _randomString(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return Iterable.generate(len, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }

  Future<String> _generateToken() async {
    final svc = LiveKitService();
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

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _listener?.dispose();
    _disconnect();
    super.dispose();
  }

  void _setupRoomListeners() {
    if (_room == null) return;

    _listener = _room!.createListener();

    _listener!
      ..on<RoomConnectedEvent>((event) {
        if (mounted) {
          setState(() {
            _isConnected = true;
            _isConnecting = false;
          });
          _waveController.repeat(reverse: true);
        }
      })
      ..on<RoomDisconnectedEvent>((event) {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _isMicEnabled = false;
            _isConnecting = false;
          });
          _waveController.stop();
          _waveController.reset();
        }
      })
      ..on<LocalTrackPublishedEvent>((event) {
        if (event.publication.kind == TrackType.AUDIO && mounted) {
          setState(() {
            _isMicEnabled = true;
          });
        }
      })
      ..on<LocalTrackUnpublishedEvent>((event) {
        if (event.publication.kind == TrackType.AUDIO && mounted) {
          setState(() {
            _isMicEnabled = false;
          });
        }
      })
      ..on<TrackMutedEvent>((event) {
        if (event.publication.kind == TrackType.AUDIO &&
            event.participant is LocalParticipant &&
            mounted) {
          setState(() {
            _isMicEnabled = false;
          });
        }
      })
      ..on<TrackUnmutedEvent>((event) {
        if (event.publication.kind == TrackType.AUDIO &&
            event.participant is LocalParticipant &&
            mounted) {
          setState(() {
            _isMicEnabled = true;
          });
        }
      });
  }

  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  Future<void> _connect() async {
    if (_isConnecting || _isConnected) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) {
        _showError('Microphone permission is required');
        setState(() {
          _isConnecting = false;
        });
        return;
      }

      final token = await _generateToken(); // Generate token here

      _room = Room();
      _setupRoomListeners();

      await _room!.connect(
        widget.url,
        token,
        connectOptions: const ConnectOptions(
          autoSubscribe: true,
        ),
      );

      await _enableMicrophone();
    } catch (e) {
      _showError('Failed to connect: $e');
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    if (!_isConnected && !_isConnecting) return;

    try {
      _listener?.dispose();
      _listener = null;
      await _room?.disconnect();
      await _room?.dispose();
      _room = null;
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isConnecting = false;
          _isMicEnabled = false;
        });
      }
      _waveController.stop();
      _waveController.reset();
    } catch (e) {
      _showError('Failed to disconnect: $e');
    }
  }

  Future<void> _enableMicrophone() async {
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(true);
    } catch (e) {
      _showError('Failed to enable microphone: $e');
    }
  }

  Future<void> _toggleMicrophone() async {
    try {
      final newState = !_isMicEnabled;
      await _room?.localParticipant?.setMicrophoneEnabled(newState);
    } catch (e) {
      _showError('Failed to toggle microphone: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPosition = Offset(
        _currentPosition.dx + details.delta.dx,
        _currentPosition.dy + details.delta.dy,
      );
    });
    widget.onPositionChanged?.call(_currentPosition);
  }

  Widget _buildConnectedView() {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.theme.connectedGradientStart,
                widget.theme.connectedGradientEnd,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(widget.height / 2),
            boxShadow: [
              BoxShadow(
                color: widget.theme.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isMicEnabled)
                        Container(
                          width: 24 + (_waveAnimation.value * 8),
                          height: 24 + (_waveAnimation.value * 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.theme.waveColor.withOpacity(
                              0.3 * (1 - _waveAnimation.value),
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: _toggleMicrophone,
                        child: Icon(
                          _isMicEnabled ? Icons.mic : Icons.mic_off,
                          color: widget.theme.iconColor,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    _isMicEnabled ? 'Listening...' : 'Muted',
                    style: TextStyle(
                      color: widget.theme.textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: GestureDetector(
                    onTap: _disconnect,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.theme.disconnectButtonColor,
                      ),
                      child: Icon(
                        Icons.close,
                        color: widget.theme.iconColor,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDisconnectedView() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isConnecting ? _pulseAnimation.value : 1.0,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.theme.disconnectedGradientStart,
                  widget.theme.disconnectedGradientEnd,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(widget.height / 2),
              boxShadow: [
                BoxShadow(
                  color: widget.theme.shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isConnecting ? null : _connect,
                borderRadius: BorderRadius.circular(widget.height / 2),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: _isConnecting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    widget.theme.iconColor,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.mic,
                                color: widget.theme.iconColor,
                                size: 20,
                              ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          _isConnecting ? 'Connecting...' : 'Tap to Connect',
                          style: TextStyle(
                            color: widget.theme.textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(flex: 1, child: SizedBox()),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double? left, top, right, bottom;
    const margin = 24.0;

    switch (widget.position) {
      case AssistantPosition.bottomRight:
        right = margin;
        bottom = margin;
        break;
      case AssistantPosition.bottomLeft:
        left = margin;
        bottom = margin;
        break;
      case AssistantPosition.topLeft:
        left = margin;
        top = margin;
        break;
      case AssistantPosition.topRight:
        right = margin;
        top = margin;
        break;
    }

    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: GestureDetector(
        child: _isConnected ? _buildConnectedView() : _buildDisconnectedView(),
      ),
    );
  }
}

class VoiceAssistantTheme {
  final Color connectedGradientStart;
  final Color connectedGradientEnd;
  final Color disconnectedGradientStart;
  final Color disconnectedGradientEnd;
  final Color iconColor;
  final Color textColor;
  final Color shadowColor;
  final Color waveColor;
  final Color disconnectButtonColor;

  const VoiceAssistantTheme({
    this.connectedGradientStart = const Color(0xFF4CAF50),
    this.connectedGradientEnd = const Color(0xFF2E7D32),
    this.disconnectedGradientStart = const Color(0xFF9E9E9E),
    this.disconnectedGradientEnd = const Color(0xFF616161),
    this.iconColor = Colors.white,
    this.textColor = Colors.white,
    this.shadowColor = const Color(0x40000000),
    this.waveColor = Colors.white,
    this.disconnectButtonColor = const Color(0x30FFFFFF),
  });

  static const VoiceAssistantTheme dark = VoiceAssistantTheme(
    connectedGradientStart: Color(0xFF1E88E5),
    connectedGradientEnd: Color(0xFF0D47A1),
    disconnectedGradientStart: Color(0xFF424242),
    disconnectedGradientEnd: Color(0xFF212121),
  );

  static const VoiceAssistantTheme purple = VoiceAssistantTheme(
    connectedGradientStart: Color(0xFF9C27B0),
    connectedGradientEnd: Color(0xFF4A148C),
    disconnectedGradientStart: Color(0xFF9E9E9E),
    disconnectedGradientEnd: Color(0xFF616161),
  );
}
