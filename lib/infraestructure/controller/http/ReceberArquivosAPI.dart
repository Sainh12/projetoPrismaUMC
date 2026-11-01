import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_multipart/form_data.dart';
import 'package:shelf_multipart/multipart.dart';

class requestReceberVideos {
  final router = Router();

  void receberVideos() async {
    router.post('/api/upload', (Request request) async {
      if (!request.isMultipart) {
        return Response.badRequest(
          body: 'Requisição não é multipart/form-data',
        );
      }
      try {
        await for (final formData in request.multipartFormData) {
          if (formData.name == 'imagem') {
            final nomeArquivo =
                formData.filename ??
                'upload_${DateTime.now().millisecondsSinceEpoch}.mp4';

            //definimos a pasta onde iremos salvar e como será o nome do arquivo salvo
            final pastaUpload = Directory('uploads');
            if (!await pastaUpload.exists()) {
              await pastaUpload.create();
            }
            final caminhoFinal = '${pastaUpload.path}/$nomeArquivo';
            final arquivoLocal = File(caminhoFinal);

            final sink = arquivoLocal.openWrite();
            await formData.part.pipe(
              sink,
            ); //escreve o fluxo de bytes diretamente no disco
            await sink.close();

            print("Arquivo recebido e salvo em: $caminhoFinal");
            return Response.ok("Imagem salva com sucesso");
          }
        }
        return Response.badRequest(
          body: "Nenhum arquivo de imagem foi enviado",
        );
      } catch (e) {
        return Response.internalServerError(body: 'Erro ao processar');
      }
    });

    final servidor = await io.serve(router, 'localhost'/*InternetAddress.anyIPv4*/ , 8080);
    print('Servidor rodando em http://${servidor.address.host}:${servidor.port}');
  }
  
}
