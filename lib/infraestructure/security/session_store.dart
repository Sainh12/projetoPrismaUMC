import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';

class SessionStore {
  SessionStore({this.lifetime = const Duration(hours: 2)})
    : _random = Random.secure();

  final Duration lifetime;
  final Random _random;
  final Map<String, _Session> _sessions = {};

  String create(String userId) {
    final now = DateTime.now();
    _sessions.removeWhere((_, session) => !session.expiresAt.isAfter(now));
    final token = base64Url
        .encode(List<int>.generate(32, (_) => _random.nextInt(256)))
        .replaceAll('=', '');
    _sessions[token] = _Session(userId, now.add(lifetime));
    return token;
  }

  String? userIdFor(Request request) {
    final token = tokenFor(request);
    if (token == null) return null;
    final session = _sessions[token];
    if (session == null) return null;
    if (!session.expiresAt.isAfter(DateTime.now())) {
      _sessions.remove(token);
      return null;
    }
    return session.userId;
  }

  bool revoke(Request request) {
    final token = tokenFor(request);
    return token != null && _sessions.remove(token) != null;
  }

  void revokeUser(String userId) {
    _sessions.removeWhere((_, session) => session.userId == userId);
  }

  String? tokenFor(Request request) {
    final authorization = request.headers['authorization'];
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      return null;
    }
    final token = authorization.substring(7).trim();
    return token.isEmpty ? null : token;
  }
}

class _Session {
  const _Session(this.userId, this.expiresAt);

  final String userId;
  final DateTime expiresAt;
}
