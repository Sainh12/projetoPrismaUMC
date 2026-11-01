import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_multipart/form_data.dart';
import 'package:shelf_multipart/multipart.dart';

class requestReceberVideos {
  final router = Router();

  static const _extensoesPermitidas = {'.mp4', '.mov', '.avi', '.mkv', '.webm'};
  static const _camposAceitos = {'video', 'imagem'};

  Future<void> iniciarServidor() async {
    router.post('/api/upload', _uploadVideo);
    final servidor = await io.serve(
      const Pipeline().addMiddleware(logRequests()).addHandler(router.call),
      'localhost' /*InternetAddress.anyIPv4*/,
      8080,
    );
    print(
      'Servidor rodando em http://${servidor.address.host}:${servidor.port}',
    );
  }

  Future<Response> _uploadVideo(Request request) async {
    
      if (!request.isMultipart) {
        return Response.badRequest(
          body: 'Requisição não é multipart/form-data',
        );
      }

      try {
        await for (final formData in request.multipartFormData) {
          if (!_camposAceitos.contains(formData.name))
            continue; //ignora campos não aceitos

          //sanitiza: p.basename remove qualquer caminho
          final originalName = p.basename(
            formData.filename ??
                'upload_${DateTime.now().millisecondsSinceEpoch}.mp4',
          );
          final extensao = p.extension(originalName).toLowerCase();
          if (!_extensoesPermitidas.contains(extensao)) {
            return Response(415, body: 'Formato não suportado. $extensao');
          }

          //definimos a pasta onde iremos salvar e como será o nome do arquivo salvo
          final pastaUpload = Directory('uploads');
          if (!await pastaUpload.exists()) {
            await pastaUpload.create();
          }

          final nomeArquivo =
              '${DateTime.now().millisecondsSinceEpoch}$originalName';

          final caminhoFinal = File(p.join(pastaUpload.path, nomeArquivo));

          final sink = caminhoFinal.openWrite();
          try {
            await formData.part.pipe(
              // Grava em streaming: não carrega o vídeo inteiro na memória
              sink, //escreve o fluxo de bytes diretamente no disco
            );
          } catch (e) {
            await sink.close();
            if (await caminhoFinal.exists()) {
              await caminhoFinal.delete();
              rethrow;
            }

            print("Arquivo recebido e salvo em: $caminhoFinal");
            return Response.ok("Arquivo salvo com sucesso");
          }
        }
        return Response.badRequest(body: "Nenhum arquivo foi enviado");
      } catch (e, st) {
        print('Erro ao processar upload: $e\n$st');
        return Response.internalServerError(body: 'Erro ao processar');
      }
    }
  
}
