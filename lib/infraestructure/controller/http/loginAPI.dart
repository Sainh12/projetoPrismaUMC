import 'dart:convert';

import 'package:projeto_base_prisma/infraestructure/repository/gerenciadoBancoDeDados.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:projeto_base_prisma/domain/Aluno.dart';
import 'package:projeto_base_prisma/domain/User.dart';
import 'package:projeto_base_prisma/domain/Professor.dart';

class loginApi {
  final router = Router();
  final GerenciadorBancoDeDados gerenciador = GerenciadorBancoDeDados();
  void start() async {
    router.get("/api/test", _getTest);
    router.get("/api/users/info", _getUser);
    router.post("/api/users/cadastrar", _postLogin);
    router.get("/api/users/acesso", _enterSystem);
    router.get("/api/users/atualizar", _atualizarUsuario);
    router.delete("/api/users/deletar", _deletarUsuario);
    //router.post("/api/users/professor", _postProfessor);
    //router.post("/api/users/aluno", _postAluno);
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);
    final server = await shelf_io.serve(handler, 'localhost', 8080);
    print('API rodando em http://${server.address.host}:${server.port}');
  }

  //====================================================================
  Future<Response> _getTest(Request request) async {
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
  }

  //====================================================================
  Future<Response> _getUser(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, Object?>;
      final emailRecebido = data['email'] as String;
      final User? user = await gerenciador.getUserByEmail(emailRecebido);

      if (user == null) {
        return Response.notFound(
          jsonEncode({'message': 'Usuário não encontrado'}),
          headers: {'content-type': 'application/json; charset = utf-8'},
        );
      }
      return Response.ok(
        jsonEncode({'message': 'Requisição GET recebida com sucesso'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e) {
      return Response.badRequest(
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  //====================================================================
  Future<Response> _postLogin(Request request) async {
    {
      //Lê o corpo da requisição
      final body = await request.readAsString();

      //Converter o JSON recebido em um mapa Dart
      final data = jsonDecode(body) as Map<String, dynamic>;

      //Acesso ao Banco de dados
      int resposta = 0 ;

      //Acessas os valores
      if (data['tipo_usuario'] == 'professor') {
        final professor = Professor.fromJson(data);
        resposta = await gerenciador.insertUser(professor);
      } else if (data['tipo_usuario'] == 'aluno'){
        final aluno = Aluno.fromJson(data);
        resposta = await gerenciador.insertUser(aluno);
      }

      //Resposta para o flutter
      if (resposta == 1) {
        return Response(
          201,
          body: jsonEncode({'message': 'Usuário recebido com sucesso'}),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return Response(
        409,
        body: jsonEncode({'message': 'usuario já existente'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  //========================================================================
  Future<Response> _enterSystem(Request request) async {
    //Formatando informações para trabalhar com elas
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    //Acesso ao Banco de dados
    final bool resposta = await gerenciador.getUserByEmailAndPassword(
      data['email'],
      data['senha'],
    );

    if (resposta) {
      return Response.ok(
        jsonEncode({'message': 'Usuario encontrado com sucesso'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return Response(
      404,
      body: jsonEncode({'message': 'Usuário não encontrado'}),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

//========================================================================

Future<Response> _atualizarUsuario(Request request) async {
  final body = await request.readAsString();
  final data = jsonDecode(body) as Map<String, dynamic>;
  int resposta = 0;
  
  if (data['tipo_usuario'] == 'professor'){
    final professor = Professor.fromJson(data);
    resposta = await gerenciador.atualizacaoUsuario(professor);
  } else if (data['tipo_usuario'] == 'aluno'){
    final aluno = Aluno.fromJson(data);
    resposta = await gerenciador.atualizacaoUsuario(aluno);
  }
  //Resposta para o flutter
      if (resposta == 1) {
        return Response(
          204,
          body: jsonEncode({'message': 'Usuário atualizado com sucesso'}),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return Response(
        404,
        body: jsonEncode({'message': 'usuario não encontrado'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}

//========================================================================
  /*Para usar o DELETE antes faça um GET para acessar os dados do user
  e ent vc salva esses dados em um objeto e usa eles para FAZER O INSERT
  O DELETE USAR O ID DO USUARIO, que SÓ TEM NO BANCO*/
  

  Future<Response> _deletarUsuario(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String,dynamic>;
    int resposta = 0;
    
    if (data['tipo_usuario'] == 'professor'){
    final professor = Professor.fromJson(data);
    resposta = await gerenciador.deletarUser(professor);
  } else if (data['tipo_usuario'] == 'aluno'){
    final aluno = Aluno.fromJson(data);
    resposta = await gerenciador.deletarUser(aluno);
  }
      //Resposta para o flutter
      if (resposta == 1)  {
        return Response(
          200,
          body: jsonEncode({'message': 'Usuário deletado com sucesso'}),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return Response(
        404,
        body: jsonEncode({'message': 'usuario não encontrado'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
  }
}
//========================================================================
/*Future<Response> _postProfessor(Request request) async {
  //Lê o corpo da requisição
  final body = await request.readAsString();

  //Converter o JSON recebido em um mapa Dart
  final data = jsonDecode(body) as Map<String, dynamic>;

  //Acessas os valores
  final String nome = data['nome'] as String;
  final String email = data['email'] as String;
  final String senha = data['senha'] as String;
  final String escola = data['escola'] as String;
  final String materia = data['materia'] as String;

  print('Recebido: nome=$nome, email=$email, escola=$escola, materia=$materia');

  //Resposta para o flutter

  return Response(
    201,
    body: jsonEncode({'message': 'Usuário recebido com sucesso'}),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

//==================================================================
Future<Response> _postAluno(Request request) async {
  //Lê o corpo da requisição
  final body = await request.readAsString();

  //Converter o JSON recebido em um mapa Dart
  final data = jsonDecode(body) as Map<String, dynamic>;

  //Acessas os valores
  final String nome = data['nome'] as String;
  final String email = data['email'] as String;
  final String senha = data['senha'] as String;
  final String escola = data['escola'] as String;
  final String serie = data['serie'] as String;
  final String turma = data['turma'] as String;

  print(
    'Recebido: nome=$nome, email=$email, escola=$escola, serie=$serie, turma=$turma',
  );

  //Resposta para o flutter

  return Response(
    201,
    body: jsonEncode({'message': 'Usuário recebido com sucesso'}),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}*/
