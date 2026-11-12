import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:projeto_base_prisma/infraestructure/security/session_store.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_multipart/form_data.dart';
import 'package:shelf_multipart/multipart.dart';
import 'package:uuid/uuid.dart';

class FileController {
  FileController({
    required this.sessions,
    required this.isProfessor,
    Directory? uploadDirectory,
    this.maxUploadBytes = 100 * 1024 * 1024,
  }) : uploadDirectory = uploadDirectory ?? Directory('uploads') {
    if (maxUploadBytes <= 0) {
      throw ArgumentError.value(maxUploadBytes, 'maxUploadBytes');
    }
    router.post('/api/upload', _uploadVideo);
    router.get('/api/videos', _listVideos);
    router.get('/api/my-videos', _listMyVideos);
    router.get('/api/video/<videoName>', _getVideo);
    router.delete('/api/video/<videoName>', _deleteVideo);
  }

  final SessionStore sessions;
  final Future<bool> Function(String userId) isProfessor;
  final Directory uploadDirectory;
  final int maxUploadBytes;
  final Router router = Router();

  static const _allowedExtensions = {'.mp4', '.mov', '.avi', '.mkv', '.webm'};
  static const _acceptedFields = {'video', 'file', 'arquivo'};
  static const _mimeTypes = {
    '.mp4': 'video/mp4',
    '.mov': 'video/quicktime',
    '.avi': 'video/x-msvideo',
    '.mkv': 'video/x-matroska',
    '.webm': 'video/webm',
  };

  Handler get handler =>
      const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

  Future<HttpServer> start({InternetAddress? address, int port = 8081}) =>
      io.serve(handler, address ?? InternetAddress.anyIPv4, port);

  Future<void> deleteUserFiles(String userId) async {
    final directory = _directoryForUser(userId);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<Response> _uploadVideo(Request request) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    if (!await isProfessor(userId)) {
      return _json(403, {
        'message': 'Apenas professores podem publicar vídeos',
      });
    }
    if (!request.isMultipart) {
      return _json(400, {'message': 'Envie multipart/form-data'});
    }

    try {
      await for (final formData in request.multipartFormData) {
        if (!_acceptedFields.contains(formData.name)) continue;

        final originalName = p.basename(
          formData.filename ?? 'upload_${const Uuid().v4()}.mp4',
        );
        final extension = p.extension(originalName).toLowerCase();
        if (!_allowedExtensions.contains(extension)) {
          return _json(415, {'message': 'Formato de vídeo não suportado'});
        }

        final userDirectory = _directoryForUser(userId);
        await userDirectory.create(recursive: true);
        final savedName = '${const Uuid().v4()}$extension';
        final destination = File(p.join(userDirectory.path, savedName));
        final sink = destination.openWrite();
        try {
          await _limitUploadSize(formData.part, maxUploadBytes).pipe(sink);
        } on _UploadTooLargeException {
          if (await destination.exists()) await destination.delete();
          return _json(413, {
            'message':
                'Arquivo excede o limite de ${maxUploadBytes ~/ (1024 * 1024)} MiB',
          });
        } catch (_) {
          if (await destination.exists()) await destination.delete();
          rethrow;
        }
        return _json(201, {'message': 'Arquivo salvo', 'name': savedName});
      }
    } on FormatException {
      return _json(400, {'message': 'Formulário multipart inválido'});
    } on IOException catch (error, stackTrace) {
      stderr.writeln('Erro ao salvar upload: $error\n$stackTrace');
      return _json(500, {'message': 'Não foi possível salvar o arquivo'});
    }
    return _json(400, {'message': 'Nenhum arquivo de vídeo foi enviado'});
  }

  Future<Response> _listVideos(Request request) async {
    if (sessions.userIdFor(request) == null) return _unauthorized();

    final videos = <Map<String, Object?>>[];
    if (await uploadDirectory.exists()) {
      await for (final ownerDirectory in uploadDirectory.list(
        followLinks: false,
      )) {
        if (ownerDirectory is! Directory) continue;
        await for (final entity in ownerDirectory.list(followLinks: false)) {
          if (entity is! File ||
              !_allowedExtensions.contains(
                p.extension(entity.path).toLowerCase(),
              )) {
            continue;
          }
          final stat = await entity.stat();
          videos.add({
            'name': p.basename(entity.path),
            'uploaded_at': stat.modified.toUtc().toIso8601String(),
          });
        }
      }
    }
    videos.sort(
      (left, right) => (right['uploaded_at'] as String).compareTo(
        left['uploaded_at'] as String,
      ),
    );
    return _json(200, {'videos': videos});
  }

  Future<Response> _listMyVideos(Request request) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    if (!await isProfessor(userId)) {
      return _json(403, {
        'message': 'Apenas professores podem listar seus vídeos',
      });
    }

    final videos = <Map<String, Object?>>[];
    final userDirectory = _directoryForUser(userId);
    if (await userDirectory.exists()) {
      await for (final entity in userDirectory.list(followLinks: false)) {
        if (entity is! File ||
            !_allowedExtensions.contains(
              p.extension(entity.path).toLowerCase(),
            )) {
          continue;
        }
        final stat = await entity.stat();
        videos.add({
          'name': p.basename(entity.path),
          'uploaded_at': stat.modified.toUtc().toIso8601String(),
        });
      }
    }
    videos.sort(
      (left, right) => (right['uploaded_at'] as String).compareTo(
        left['uploaded_at'] as String,
      ),
    );
    return _json(200, {'videos': videos});
  }

  Future<Response> _getVideo(Request request, String name) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    final safeName = p.basename(name);
    final file = await _findVideo(safeName);
    if (file == null) {
      return _json(404, {'message': 'Vídeo não encontrado'});
    }

    final length = await file.length();
    final extension = p.extension(safeName).toLowerCase();
    final contentType = _mimeTypes[extension] ?? 'application/octet-stream';
    final range = request.headers['range'];
    if (range == null) {
      return Response.ok(
        file.openRead(),
        headers: {
          'content-type': contentType,
          'content-length': length.toString(),
          'accept-ranges': 'bytes',
        },
      );
    }

    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
    if (match == null || length == 0) return _rangeNotSatisfiable(length);
    final startText = match.group(1)!;
    final endText = match.group(2)!;
    if (startText.isEmpty && endText.isEmpty) {
      return _rangeNotSatisfiable(length);
    }

    late final int start;
    late final int end;
    if (startText.isEmpty) {
      final suffixLength = int.tryParse(endText);
      if (suffixLength == null || suffixLength <= 0) {
        return _rangeNotSatisfiable(length);
      }
      start = suffixLength >= length ? 0 : length - suffixLength;
      end = length - 1;
    } else {
      start = int.tryParse(startText) ?? -1;
      end = endText.isEmpty ? length - 1 : (int.tryParse(endText) ?? -1);
    }

    if (start < 0 || end < start || start >= length) {
      return _rangeNotSatisfiable(length);
    }
    final boundedEnd = end >= length ? length - 1 : end;
    final partLength = boundedEnd - start + 1;
    return Response(
      206,
      body: file.openRead(start, boundedEnd + 1),
      headers: {
        'content-type': contentType,
        'content-length': partLength.toString(),
        'content-range': 'bytes $start-$boundedEnd/$length',
        'accept-ranges': 'bytes',
      },
    );
  }

  Future<Response> _deleteVideo(Request request, String name) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    if (!await isProfessor(userId)) {
      return _json(403, {'message': 'Apenas professores podem excluir vídeos'});
    }
    final safeName = p.basename(name);
    final file = File(p.join(_directoryForUser(userId).path, safeName));
    if (!await file.exists()) {
      return _json(404, {'message': 'Vídeo não encontrado'});
    }

    try {
      await file.delete();
      return _json(200, {'deletado': safeName});
    } on FileSystemException catch (error, stackTrace) {
      stderr.writeln('Erro ao excluir vídeo: $error\n$stackTrace');
      return _json(500, {'message': 'Não foi possível excluir o vídeo'});
    }
  }

  Response _rangeNotSatisfiable(int length) =>
      Response(416, headers: {'content-range': 'bytes */$length'});

  Future<File?> _findVideo(String name) async {
    if (!await uploadDirectory.exists()) return null;
    await for (final ownerDirectory in uploadDirectory.list(
      followLinks: false,
    )) {
      if (ownerDirectory is! Directory) continue;
      final file = File(p.join(ownerDirectory.path, name));
      if (await file.exists()) return file;
    }
    return null;
  }

  Directory _directoryForUser(String userId) {
    final userKey = base64Url.encode(utf8.encode(userId)).replaceAll('=', '');
    return Directory(p.join(uploadDirectory.path, userKey));
  }

  Response _unauthorized() =>
      _json(401, {'message': 'Autenticação necessária'});

  Response _json(int statusCode, Object body) => Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Stream<List<int>> _limitUploadSize(
    Stream<List<int>> stream,
    int maxBytes,
  ) async* {
    var totalBytes = 0;
    await for (final chunk in stream) {
      totalBytes += chunk.length;
      if (totalBytes > maxBytes) throw const _UploadTooLargeException();
      yield chunk;
    }
  }
}

class _UploadTooLargeException implements Exception {
  const _UploadTooLargeException();
}
