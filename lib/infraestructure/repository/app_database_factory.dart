import 'package:sqflite_common/sqlite_api.dart';

DatabaseFactory? _configuredDatabaseFactory;

DatabaseFactory get appDatabaseFactory =>
    _configuredDatabaseFactory ??
    (throw StateError('O driver SQLite não foi configurado.'));

void configureDatabaseFactory(DatabaseFactory factory) {
  _configuredDatabaseFactory = factory;
}
