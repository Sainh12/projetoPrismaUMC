import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:projeto_base_prisma/domain/pergunta_rascunho.dart';
import 'package:projeto_base_prisma/infraestructure/repository/app_database_factory.dart';
import 'package:projeto_base_prisma/infraestructure/repository/database_helper_quiz.dart';
import 'package:projeto_base_prisma/infraestructure/repository/database_helper_users.dart';
import 'package:projeto_base_prisma/infraestructure/repository/quiz_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  test(
    'migrates legacy questions and persists quiz lifecycle in SQLite',
    () async {
      sqfliteFfiInit();
      final factory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp('prisma-quiz-');
      await factory.setDatabasesPath(directory.path);
      configureDatabaseFactory(factory);

      Database? quizDb;
      Database? usersDb;
      addTearDown(() async {
        if (quizDb != null) await quizDb.close();
        if (usersDb != null) await usersDb.close();
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final legacyDb = await factory.openDatabase(
        p.join(directory.path, 'quiz.db'),
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE Perguntas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              professor_id TEXT NOT NULL,
              enunciado TEXT NOT NULL,
              resposta_correta TEXT NOT NULL,
              data_criacao TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
          ''');
          },
        ),
      );
      await legacyDb.insert('Perguntas', {
        'professor_id': 'professor-1',
        'enunciado': 'Questão antiga',
        'resposta_correta': 'Resposta antiga',
      });
      await legacyDb.close();

      usersDb = await DatabaseHelperUsers.instance.database;
      await usersDb.insert('Usuarios', {
        'usuario_id': 'professor-1',
        'nome_completo': 'Professora',
        'cpf': '12345678901',
        'email': 'professora@example.test',
        'senha': 'hash',
        'escola': 'Escola',
        'tipo_usuario': 'professor',
      });
      await usersDb.insert('Professores', {
        'id': 'professor-1',
        'materia': 'Matemática',
        'cndb': 'CNDB-1',
      });

      quizDb = await DatabaseHelperQuiz.instance.database;
      final repository = SqliteQuizRepository();
      final migratedQuizzes = await repository.listarQuizzes(
        professorId: 'professor-1',
        publicadosApenas: false,
      );
      expect(migratedQuizzes, hasLength(1));
      expect(migratedQuizzes.single.titulo, 'Matemática');
      expect(migratedQuizzes.single.status, 'draft');
      final oldQuestions = await repository.listarPerguntas(
        quizId: migratedQuizzes.single.id,
      );
      expect(oldQuestions.single.enunciado, 'Questão antiga');
      expect(oldQuestions.single.alternativas, isEmpty);

      final newQuizId = await repository.criarQuiz(
        'professor-1',
        'aula-nova.mp4',
        'Matemática',
      );
      await repository.salvarPerguntas(newQuizId, 'professor-1', const [
        PerguntaRascunho(
          enunciado: 'Quanto é 2 + 2?',
          alternativas: ['3', '4', '5', '6'],
          respostaCorreta: '4',
        ),
      ]);
      expect(await repository.publicarQuiz(newQuizId, 'professor-1'), 1);
      final published = await repository.listarQuizzes(publicadosApenas: true);
      expect(published, hasLength(1));
      expect(published.single.id, newQuizId);

      await repository.salvarPerguntas(newQuizId, 'professor-1', const [
        PerguntaRascunho(
          enunciado: 'Questão atualizada',
          alternativas: ['A', 'B', 'C', 'D'],
          respostaCorreta: 'A',
        ),
      ]);
      expect(await repository.listarQuizzes(publicadosApenas: true), isEmpty);
      final savedAsDraft = await repository.listarQuizzes(
        professorId: 'professor-1',
        publicadosApenas: false,
      );
      expect(
        savedAsDraft.singleWhere((quiz) => quiz.id == newQuizId).status,
        'draft',
      );
      expect(await repository.publicarQuiz(newQuizId, 'professor-1'), 1);

      await repository.registrarTentativa(
        quizId: newQuizId,
        alunoId: 'aluno-1',
        acertos: 1,
        totalQuestoes: 1,
        nota: 10,
      );
      await repository.registrarTentativa(
        quizId: newQuizId,
        alunoId: 'aluno-1',
        acertos: 0,
        totalQuestoes: 1,
        nota: 0,
      );
      final attempts = await repository.listarTentativas(newQuizId, 'aluno-1');
      expect(attempts, hasLength(2));
      expect(attempts.first.nota, 0);
      expect(attempts.last.nota, 10);

      expect(await repository.excluirQuiz(newQuizId, 'professor-1'), 1);
      expect(await repository.buscarQuiz(newQuizId), isNull);
      expect(await repository.listarPerguntas(quizId: newQuizId), isEmpty);
      expect(await repository.listarTentativas(newQuizId, 'aluno-1'), isEmpty);
    },
  );
}
