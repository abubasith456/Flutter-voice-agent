import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

class AIVoiceAssistantWidget extends StatefulWidget {
  final String token;
  final String serverUrl;
  final AlignmentGeometry position;
  final Color primaryColor;
  final Color backgroundColor;
  final Color iconColor;
  final double size;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;
  final Function(String)? onError;
  final Function(String)? onSpeechReceived;
  final bool showStatusIndicator;
  final String? connectingText;
  final String? connectedText;
  final String? disconnectedText;

  const AIVoiceAssistantWidget({
    Key? key,
    required this.token,
    required this.serverUrl,
    this.position = Alignment.bottomRight,
    this.primaryColor = Colors.blue,
    this.backgroundColor = Colors.white,
    this.iconColor = Colors.black87,
    this.size = 60.0,
    this.borderRadius,
    this.margin = const EdgeInsets.all(20.0),
    this.padding = const EdgeInsets.all(12.0),
    this.onConnected,
    this.onDisconnected,
    this.onError,
    this.onSpeechReceived,
    this.showStatusIndicator = true,
    this.connectingText = "Connecting...",
    this.connectedText = "Connected",
    this.disconnectedText = "Disconnected",
  }) : super(key: key);

  @override
  State<AIVoiceAssistantWidget> createState() => _AIVoiceAssistantWidgetState();
}

class _AIVoiceAssistantWidgetState extends State<AIVoiceAssistantWidget>
    with TickerProviderStateMixin {
  lk.Room? _room;
  lk.LocalAudioTrack? _audioTrack;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isMicrophoneEnabled = false;
  bool _hasPermissions = false;
  String _statusText = "";

  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkPermissions();
    _statusText = widget.disconnectedText ?? "Disconnected";
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  Future<void> _checkPermissions() async {
    final microphonePermission = await Permission.microphone.status;
    setState(() {
      _hasPermissions = microphonePermission == PermissionStatus.granted;
    });
  }

  Future<bool> _requestPermissions() async {
    final microphonePermission = await Permission.microphone.request();
    final hasPermissions = microphonePermission == PermissionStatus.granted;

    setState(() {
      _hasPermissions = hasPermissions;
    });

    return hasPermissions;
  }

  Future<void> _connectToRoom() async {
    if (_isConnecting || _isConnected) return;

    if (!_hasPermissions) {
      final granted = await _requestPermissions();
      if (!granted) {
        widget.onError?.call("Microphone permission denied");
        return;
      }
    }

    setState(() {
      _isConnecting = true;
      _statusText = widget.connectingText ?? "Connecting...";
    });

    try {
      _room = lk.Room();

      // Set up room listeners
      _room!.addListener(_onRoomUpdate);

      // Connect to room
      await _room!.connect(
        widget.serverUrl,
        widget.token,
        connectOptions: const lk.ConnectOptions(
          autoSubscribe: true,
        ),
      );

      // Create and publish audio track
      await _enableMicrophone();

      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _statusText = widget.connectedText ?? "Connected";
      });

      widget.onConnected?.call();
      _startRippleEffect();
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _statusText = widget.disconnectedText ?? "Disconnected";
      });
      widget.onError?.call("Connection failed: ${e.toString()}");
    }
  }

  Future<void> _disconnectFromRoom() async {
    if (_room != null) {
      await _disableMicrophone();
      _room!.removeListener(_onRoomUpdate);
      await _room!.disconnect();
      _room = null;
    }

    setState(() {
      _isConnected = false;
      _isConnecting = false;
      _isMicrophoneEnabled = false;
      _statusText = widget.disconnectedText ?? "Disconnected";
    });

    widget.onDisconnected?.call();
  }

  Future<void> _enableMicrophone() async {
    if (_audioTrack != null) return;

    try {
      _audioTrack =
          await lk.LocalAudioTrack.create(const lk.AudioCaptureOptions(
        noiseSuppression: true,
        echoCancellation: true,
        autoGainControl: true,
      ));

      await _room!.localParticipant?.publishAudioTrack(_audioTrack!);

      setState(() {
        _isMicrophoneEnabled = true;
      });
    } catch (e) {
      widget.onError?.call("Failed to enable microphone: ${e.toString()}");
    }
  }

  Future<void> _disableMicrophone() async {
    if (_audioTrack != null) {
      await _room!.localParticipant?.unpublishAllTracks();
      await _audioTrack!.dispose();
      _audioTrack = null;

      setState(() {
        _isMicrophoneEnabled = false;
      });
    }
  }

  void _onRoomUpdate() {
    // Handle room updates, participant changes, etc.
    if (_room?.connectionState == lk.ConnectionState.connected) {
      _disconnectFromRoom();
    }
  }

  void _startRippleEffect() {
    _rippleController.reset();
    _rippleController.forward();
  }

  void _toggleConnection() {
    if (_isConnected) {
      _disconnectFromRoom();
    } else {
      _connectToRoom();
    }
  }

  Widget _buildStatusIndicator() {
    if (!widget.showStatusIndicator) return const SizedBox.shrink();

    return Positioned(
      top: widget.margin?.resolve(TextDirection.ltr).top ?? 20,
      left: widget.margin?.resolve(TextDirection.ltr).left ?? 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: widget.backgroundColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isConnected
                ? Colors.green
                : _isConnecting
                    ? Colors.orange
                    : Colors.red,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _isConnected
                    ? Colors.green
                    : _isConnecting
                        ? Colors.orange
                        : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _statusText,
              style: TextStyle(
                color: widget.iconColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isConnected && _isMicrophoneEnabled
              ? _pulseAnimation.value
              : 1.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple effect
              if (_isConnected)
                AnimatedBuilder(
                  animation: _rippleAnimation,
                  builder: (context, child) {
                    return Container(
                      width: widget.size * 2 * _rippleAnimation.value,
                      height: widget.size * 2 * _rippleAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.primaryColor.withOpacity(
                          0.3 * (1 - _rippleAnimation.value),
                        ),
                      ),
                    );
                  },
                ),
              // Main button
              Container(
                width: widget.size,
                height: widget.size,
                margin: widget.margin,
                decoration: BoxDecoration(
                  color: _isConnected
                      ? widget.primaryColor
                      : widget.backgroundColor,
                  borderRadius: widget.borderRadius ??
                      BorderRadius.circular(widget.size / 2),
                  border: Border.all(
                    color: widget.primaryColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: widget.borderRadius ??
                        BorderRadius.circular(widget.size / 2),
                    onTap: _toggleConnection,
                    child: Container(
                      padding: widget.padding,
                      child: Icon(
                        _isConnected
                            ? (_isMicrophoneEnabled ? Icons.mic : Icons.mic_off)
                            : _isConnecting
                                ? Icons.sync
                                : Icons.mic_none,
                        color: _isConnected ? Colors.white : widget.iconColor,
                        size: widget.size * 0.4,
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: widget.position,
          child: _buildVoiceButton(),
        ),
        _buildStatusIndicator(),
      ],
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _disconnectFromRoom();
    super.dispose();
  }
}

// Extension for easy integration
extension AIVoiceAssistantExtension on Widget {
  Widget withVoiceAssistant({
    required String token,
    required String serverUrl,
    AlignmentGeometry position = Alignment.bottomRight,
    Color primaryColor = Colors.blue,
    Color backgroundColor = Colors.white,
    Color iconColor = Colors.black87,
    double size = 60.0,
    VoidCallback? onConnected,
    VoidCallback? onDisconnected,
    Function(String)? onError,
  }) {
    return Stack(
      children: [
        this,
        AIVoiceAssistantWidget(
          token: token,
          serverUrl: serverUrl,
          position: position,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
          iconColor: iconColor,
          size: size,
          onConnected: onConnected,
          onDisconnected: onDisconnected,
          onError: onError,
        ),
      ],
    );
  }
}
