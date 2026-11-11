import 'dart:convert';

Map<String, dynamic> decodeApiResponseObject(
  String body, {
  required int statusCode,
  required String fallbackMessage,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    if (statusCode >= 400) {
      final detail = body.trim();
      if (detail.toLowerCase() == 'route not found') {
        throw Exception(
          'A API de vídeos respondeu HTTP $statusCode. Reinicie o servidor '
          'de arquivos para carregar a rota GET /api/videos.',
        );
      }
      throw Exception(
        detail.isEmpty
            ? '$fallbackMessage (HTTP $statusCode)'
            : '$fallbackMessage (HTTP $statusCode): $detail',
      );
    }
    throw Exception('A API retornou uma resposta inválida.');
  }

  if (decoded is! Map<String, dynamic>) {
    throw Exception('A API retornou uma resposta em formato inválido.');
  }
  if (statusCode >= 400) {
    final message = decoded['message'];
    throw Exception(
      message is String && message.isNotEmpty
          ? message
          : '$fallbackMessage (HTTP $statusCode)',
    );
  }
  return decoded;
}
