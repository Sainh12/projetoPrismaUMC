import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelperArquivos {
  DatabaseHelperArquivos._privateConstructor();

  static final DatabaseHelperArquivos instance =
      DatabaseHelperArquivos._privateConstructor();

  static Database? _database;

  Future<Database> get database async => _database ??= await _conexao();

  Future<Database> _conexao() async {
    final path = join(await getDatabasesPath(), '/var/lib/mysql');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
    CREATE TABLE arquivos (
    id INTEGER PRIMARY KEY,
    reference TEXT NOT NULL
    )
    ''');
      },
    );
  }

  
}
