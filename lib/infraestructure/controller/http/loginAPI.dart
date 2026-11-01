import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class ApiServer {
  final router = Router();
  void start() async {
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);
    final server = await shelf_io.serve(handler, 'localhost', 8080);
    print('API rodando em http://${server.address.host}:${server.port}');
  }

//====================================================================
  void getTest() async {
    router.get('/api/users', (Request request) {
      final users = [
        {
          'id': '1',
          'nome': 'Saimon',
          'email': 'saimon@hotmail.com',
          'escola': 'Escola A',
          'serie': '3° ano',
          'turma': 'A',
        },
        {
          'id': '2',
          'nome': 'João',
          'email': 'joaoxeroso@hotmail.com',
          'escola': 'Escola A',
          'serie': '3° ano',
          'turma': 'B',
        },
      ];
      return Response.ok(
        jsonEncode(users),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }

//====================================================================
  void get() async {
    router.get('/api/users', (Request request) {
      
      return Response.ok(
        jsonEncode({'message': 'Requisição GET recebida com sucesso'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }
//====================================================================
  void post() async {
    router.post("/api/users", (Request request) async {
      //Lê o corpo da requisição
      final body = await request.readAsString();

      //Converter o JSON recebido em um mapa Dart
      final data = jsonDecode(body) as Map<String, dynamic>;

      //Acessas os valores
      final String name = data['name'] as String;
      final String email = data['email'] as String;
      final String password = data['password'] as String;
      final String school = data['school'] as String;

      print(
        'Recebido: name=$name, email=$email, password=$password, school=$school',
      );

      //Resposta para o flutter

      return Response(
        201,
        body:jsonEncode({'message': 'Usuário recebido com sucesso'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }

//==================================================================
  void postProfessor() async {
    router.post("/api/users/professor", (Request request) async {
      //Lê o corpo da requisição
      final body = await request.readAsString();

      //Converter o JSON recebido em um mapa Dart
      final data = jsonDecode(body) as Map<String, dynamic>;

      //Acessas os valores
      final String name = data['name'] as String;
      final String email = data['email'] as String;
      final String password = data['password'] as String;
      final String school = data['school'] as String;
      final String materia = data['materia'] as String;

      print(
        'Recebido: name=$name, email=$email, password=$password, school=$school, materia=$materia',
      );

      //Resposta para o flutter

      return Response(
        201,
        body:jsonEncode({'message': 'Usuário recebido com sucesso'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }

//==================================================================
  void postAluno() async {
    router.post("/api/users/aluno", (Request request) async {
      //Lê o corpo da requisição
      final body = await request.readAsString();

      //Converter o JSON recebido em um mapa Dart
      final data = jsonDecode(body) as Map<String, dynamic>;

      //Acessas os valores
      final String name = data['name'] as String;
      final String email = data['email'] as String;
      final String password = data['password'] as String;
      final String school = data['school'] as String;
      final String serie = data['serie'] as String;
      final String turma = data['turma'] as String;


      print(
        'Recebido: name=$name, email=$email, password=$password, school=$school, serie=$serie, turma=$turma',
      );

      //Resposta para o flutter

      return Response(
        201,
        body:jsonEncode({'message': 'Usuário recebido com sucesso'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }
}
