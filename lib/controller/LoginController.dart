import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

void main() async{
  final router = Router();

  router.get('/api/users', (Request request){
    final users = [
      {
        'id' : '1',
        'nome' : 'Saimon',
        'email' : 'saimon@hotmail.com',
        'escola' : 'Escola A',
        'serie' : '3° ano',
        'turma' : 'A'
      },
      {
        'id' : '2',
        'nome' : 'João',
        'email' : 'joaoxeroso@hotmail.com',
        'escola' : 'Escola A',
        'serie' : '3° ano',
        'turma' : 'B'
      }
    ];
    return Response.ok(
      jsonEncode(users),
      headers: {
        'content-type' : 'application/json; charset=utf-8',
      }
    );
  });

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await shelf_io.serve(
    handler,
    'localhost',
    8080
    );
  print ('API rodando em http://${server.address.host}:${server.port}');
}