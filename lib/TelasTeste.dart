import 'dart:convert';
import 'package:flutter/material.dart';
import 'controller/LoginController.dart';
import 'model/Aluno.dart';
import 'model/Professor.dart';
import 'model/User.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp (const TelaTeste());
}

class TelaTeste extends StatelessWidget{
  const TelaTeste({super.key});

  @override
  Widget build (BuildContext context) {
    return MaterialApp(
      title: 'Tela de Teste',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const UsersPage(),
    );
  }
}

class ElevatedButtonExampleApp extends StatelessWidget{
  const ElevatedButtonExampleApp({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Professor')),
        body: const ElevatedButtonExample(),
      ),
    );
  }
}

void _abrirTelaLoginProfessor(){
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder : (context) => const TelaLoginProfessor(),
    )
  )
}


class ElevatedButtonExample extends StatefulWidget{
  const ElevatedButtonExample({super.key});

  @override
  State <ElevatedButtonExample> createState() => _ElevatedButtonExample();
}
class _ElevatedButtonExampleState extends State<ElevatedButtonExample> {

  @override
  Widget build(BuildContext context){
    final ButtonStyle style = ElevatedButton.styleFrom(
      textStyle: const TextStyle (fontSize:20),
    );

    return Center(
      child: Column(
        mainAxisSize: .min,
        children: <Widget>[
          ElevatedButton(
            style: style,
            onPressed: _abrirTelaLoginProfessor,
            child: const Text('Disabled'),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: style,
            onPressed: () {},
            child: const Text('Enabled'),
          ),
        ],
      ),
    );
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState()=> _UsersPageState();
}

class _UsersPageState extends State<UsersPage>{
  //usar localhost se a API estiver na mesma maquina
  static const String apiUrl = 'http://localhost:8080/api/users';

  late Future<List<User>> usersFuture;

  @override
  void initState(){
    super.initState();
    usersFuture = fetchUsers();
  }

  Future<List<User>> fetchUsers() async {
    final response = await http.get(Uri.parse(apiUrl));

    if(response.statusCode != 200){
      throw Exception ('Erro ao buscar usuário: ${response.statusCode}');
    }

    final List<dynamic> data = 
      jsonDecode(response.body) as List<dynamic>;

      return data.map((item) {
        return User.fromJson(item as Map<String,dynamic>);
      }).toList();
  }

  void reloadUsers(){
    setState((){
      usersFuture = fetchUsers();
    });
  }

  @override
  Widget build (BuildContext context){
    return Scaffold (
      appBar: AppBar(
        title : const Text ('Usuario da API'),
        actions : [
          IconButton(
            onPressed : reloadUsers,
            icon : const Icon(Icons.refresh),
            tooltip : 'Atualizar usuários',
          ),
        ],
      ),
      body: FutureBuilder<List<User>>(
        future: usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting){
            return const Center(child : CircularProgressIndicator());
          }
          if (snapshot.hasError){
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24), 
                child: Column (
                  mainAxisSize : MainAxisSize.min,
                  children: [
                  const Icon (Icons.error_outline , size : 48, color : Colors.red),
                  const SizedBox (height: 12), 
                  const Text(
                    'Não foi possível carregar os usuários.',
                    textAlign : TextAlign.center,
                  ),
                  const SizedBox(height : 8),
                  Text('${snapshot.error}', textAlign : TextAlign.center),
                  const SizedBox(height : 16),
                  ElevatedButton(
                    onPressed : reloadUsers,
                    child : const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          final users = snapshot.data ?? [];

          if (users.isEmpty){
            return const Center(child: Text ('Nenhum usuário encontrado'));
          }

          return ListView.builder(
            itemCount : users.length,
            itemBuilder : (context, index){
              final user = users[index];
              return Card(
                margin : const EdgeInsets.symmetric(horizontal : 16 , vertical : 6),
                child : ListTile (
                  leading: CircleAvatar (child: Text('${user.id}')),
                  title: Text(user.name),
                  subtitle: Text('ID: ${user.id}'),
                  trailing: const Icon(Icons.person_outline),
                ),
              );
            },
          );
        },
      ),
    );
  }
}