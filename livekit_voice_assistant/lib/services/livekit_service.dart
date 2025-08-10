import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;

class LiveKitService {
  Future<String> fetchToken({required String userId, required String userName}) async {
    final apiBase = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
    final uri = Uri.parse('$apiBase/getToken');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'userName': userName}),
    );
    if (response.statusCode != 200) {
      throw Exception('Token error: ${response.statusCode} ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['token'] as String;
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

    final dynamic participant = room.localParticipant;
    // publishTrack and setAttributes signatures differ across versions; call defensively
    try {
      final result = participant.publishTrack(audioTrack);
      if (result is Future) {
        await result;
      }
    } catch (_) {}

    try {
      final result = participant.setAttributes(attributes);
      if (result is Future) {
        await result;
      }
    } catch (_) {}

    return room;
  }
}