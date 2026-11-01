import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_multipart/form_data.dart';
import 'package:shelf_multipart/multipart.dart';

class fileControll {
  final router = Router();

  static const _extensoesPermitidas = {'.mp4', '.mov', '.avi', '.mkv', '.webm'};
  static const _camposAceitos = {'video', 'imagem'};

  static const _tiposMime = {
    '.mp4': 'video/mp4',
    '.mov': 'video/quicktime',
    '.avi': 'video/x-msvideo',
    '.mkv': 'video/x-matroska',
    '.webm': 'video/webm',
  };

  //inicia o servidor e define os métodos em cada rota
  Future<void> iniciarServidor() async {
    router.post('/api/upload', _uploadVideo);
    router.get('/api/video/<videoName>', _getVideo);
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
      return Response.badRequest(body: 'Requisição não é multipart/form-data');
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

  //Acessa os videos salvos e reproduz por uma requisição GET
  Future<Response> _getVideo(Request request, String nome) async {
    //sanitiza o nome para impedir que acesse o arquivo fora
    final safeName = p.basename(nome);
    final arquivo = File(p.join('uploads', safeName));

    if (!await arquivo.exists()) {
      return Response.notFound('Video não encontrado');
    }

    final tamanho = await arquivo.length();
    final tipo =
        _tiposMime[p.extension(safeName).toLowerCase()] ??
        'application/octet-stream';
    final rangeHeader = request.headers['range'];

    if (rangeHeader == null){
      return Response.ok(
        arquivo.openRead(),
        headers:{
          'content-type' : tipo,
          'content-length' : tamanho.toString(),
          'accept-ranges' : 'bytes' ,
        },
      );
    }

    //arquivo com um range definido: formato 'byte=inicio-fim' (fim opcional)

    final match = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(rangeHeader);
    if (match == null || (match.group(1)!.isEmpty && match.group(2)!.isEmpty)){
      return Response(416,headers: {'content-range' : 'bytes */$tamanho'});
    }

    int inicio;
    int fim;
    final s = match.group(1)!;
    final e = match.group(2)!;

    if (s.isEmpty) {
      //"bytes=-500" : ultimos 500 bytes
      inicio = tamanho - int.parse(e);
      fim = tamanho - 1;
    } else {
      inicio = int.parse(s);
      fim = e.isEmpty ? tamanho - 1 : int.parse(e);
    }

    if (inicio < 0) inicio = 0;
    if (fim >= tamanho) fim = tamanho - 1;

    if(inicio>= tamanho || fim < inicio){
      return Response(416, headers: {'content-range' : 'bytes */$tamanho'});
    }

    final tamanhoParte = fim - inicio + 1;

    return Response (
      206, //partial content
      body: arquivo.openRead(inicio, fim + 1),
      headers: {
        'content-type' : tipo,
        'content-length' : tamanhoParte.toString(),
        'content-range' : 'bytes $inicio-$fim/$tamanho',
        'accept-ranges' : 'bytes',
        },
    );
  }
}
