import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelperUsers{

  DatabaseHelperUsers._privateConstructor();

  static final DatabaseHelperUsers instance = DatabaseHelperUsers._privateConstructor();

  static Database? _database;

  Future<Database> get database async => _database ??= await _conexao();

  Future<Database> _conexao() async {
    final path = join(await getDatabasesPath(), '');
    return openDatabase(
      path,
      version:1,
      onCreate: (db,version){
        return db.execute('''
    CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    nome TEXT NOT NULL,
    email TEXT NOT NULL,
    escola TEXT NOT NULL,
    senha TEXT NOT NULL,
''');
      }
    );
  }
}