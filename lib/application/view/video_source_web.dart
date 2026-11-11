import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

Future<Uri> prepareVideoSource(Uri source, String accessToken) async {
  final response = await http
      .get(source, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(minutes: 2));
  if (response.statusCode != 200) {
    throw Exception(
      'A API não conseguiu carregar o vídeo (HTTP '
      '${response.statusCode}).',
    );
  }

  final contentType =
      response.headers['content-type'] ?? 'application/octet-stream';
  final blob = web.Blob(
    [response.bodyBytes.toJS].toJS,
    web.BlobPropertyBag(type: contentType),
  );
  return Uri.parse(web.URL.createObjectURL(blob));
}

void releaseVideoSource(Uri source) {
  web.URL.revokeObjectURL(source.toString());
}
