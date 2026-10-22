abstract class User {
  final String _id;
  final String _nome;
  final String _email;
  final String _senha;
  final String _escola;

  User(this._nome, this._email, this._senha, this._escola)
  : _id = (DateTime.now().millisecondsSinceEpoch * _nome.length).toString();

  String get nome => _nome;
  String get email => _email;
  String get escola => _escola;
  
}