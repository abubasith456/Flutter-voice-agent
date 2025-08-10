import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class LiveKitService {
  String generateToken({
    required String userId,
    required String userName,
    String roomName = 'voice-assistant-room',
    Duration ttl = const Duration(hours: 1),
  }) {
    final apiKey = dotenv.env['LIVEKIT_API_KEY'];
    final apiSecret = dotenv.env['LIVEKIT_API_SECRET'];
    if (apiKey == null || apiSecret == null || apiKey.isEmpty || apiSecret.isEmpty) {
      throw Exception('LIVEKIT_API_KEY/SECRET not configured');
    }

    final now = DateTime.now().toUtc();
    final exp = now.add(ttl);

    final claims = <String, dynamic>{
      'iss': apiKey,
      'sub': userId,
      'name': userName,
      'nbf': (now.millisecondsSinceEpoch / 1000).floor(),
      'exp': (exp.millisecondsSinceEpoch / 1000).floor(),
      // Include participant metadata on join (JSON string)
      'metadata': jsonEncode({
        'userId': userId,
        'userName': userName,
      }),
      'video': {
        'roomCreate': true,
        'roomJoin': true,
        'room': roomName,
        'canPublish': true,
        'canSubscribe': true,
      },
    };

    final jwt = JWT(claims);
    return jwt.sign(SecretKey(apiSecret), algorithm: JWTAlgorithm.HS256);
  }

  Future<lk.Room> connectWithMic({
    required String token,
    required Map<String, String> attributes,
  }) async {
    final url = dotenv.env['LIVEKIT_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('LIVEKIT_URL not configured');
    }

    final room = lk.Room(
      roomOptions: const lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    await room.connect(url, token);

    final audioTrack = await lk.LocalAudioTrack.create(
      lk.AudioCaptureOptions(
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
      ),
    );

    final participant = room.localParticipant;
    if (participant == null) {
      throw Exception('Local participant not available');
    }
    await participant.publishAudioTrack(audioTrack);
    try {
      participant.setAttributes(attributes);
    } catch (_) {}

    return room;
  }
}