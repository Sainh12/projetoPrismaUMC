import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projeto_base_prisma/application/theme/app_theme.dart';
import 'package:projeto_base_prisma/application/view/api_response.dart';
import 'package:projeto_base_prisma/domain/quiz_tentativa.dart';

class QuizAttemptPage extends StatefulWidget {
  const QuizAttemptPage({
    super.key,
    required this.accessToken,
    required this.quizId,
  });

  final String accessToken;
  final int quizId;

  @override
  State<QuizAttemptPage> createState() => _QuizAttemptPageState();
}

class _QuizAttemptPageState extends State<QuizAttemptPage> {
  static const _quizBaseUrl = 'http://localhost:8080/api/quiz/quizzes';

  String _quizTitle = 'Quiz';
  String _videoTitle = '';
  List<_QuizQuestion> _questions = [];
  List<QuizTentativa> _attempts = [];
  final Map<int, String> _answers = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasSubmittedCurrentAnswers = false;
  bool _isConfirmingLeave = false;
  String? _loadError;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${widget.accessToken}',
    'Content-Type': 'application/json',
  };

  bool get _hasPendingAnswers =>
      _answers.isNotEmpty && !_hasSubmittedCurrentAnswers;

  @override
  void initState() {
    super.initState();
    unawaited(_loadQuizAndHistory());
  }

  Future<void> _loadQuizAndHistory() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final quizUrl = Uri.parse('$_quizBaseUrl/${widget.quizId}');
      final attemptsUrl = Uri.parse(
        '$_quizBaseUrl/${widget.quizId}/tentativas',
      );
      final responses = await Future.wait([
        http.get(quizUrl, headers: _headers),
        http.get(attemptsUrl, headers: _headers),
      ]).timeout(const Duration(seconds: 20));
      final quizData = decodeApiResponseObject(
        responses[0].body,
        statusCode: responses[0].statusCode,
        fallbackMessage: 'Não foi possível carregar o quiz.',
      );
      final attemptsData = decodeApiResponseObject(
        responses[1].body,
        statusCode: responses[1].statusCode,
        fallbackMessage: 'Não foi possível carregar o histórico.',
      );
      final rawQuestions = quizData['questoes'];
      final rawAttempts = attemptsData['tentativas'];
      if (rawQuestions is! List || rawAttempts is! List) {
        throw Exception('A API retornou dados inválidos para o quiz.');
      }

      final questions = <_QuizQuestion>[];
      for (final rawQuestion in rawQuestions) {
        if (rawQuestion is! Map<String, dynamic>) {
          throw Exception('A API retornou uma questão inválida.');
        }
        final rawAlternatives = rawQuestion['alternativas'];
        if (rawQuestion['id'] is! int ||
            rawQuestion['enunciado'] is! String ||
            rawAlternatives is! List ||
            rawAlternatives.isEmpty ||
            rawAlternatives.any((alternative) => alternative is! String)) {
          throw Exception('A API retornou uma questão inválida.');
        }
        questions.add(
          _QuizQuestion(
            id: rawQuestion['id'] as int,
            enunciado: rawQuestion['enunciado'] as String,
            alternativas: rawAlternatives.cast<String>(),
          ),
        );
      }
      final attempts = <QuizTentativa>[];
      for (final rawAttempt in rawAttempts) {
        if (rawAttempt is! Map<String, dynamic>) {
          throw Exception('A API retornou uma tentativa inválida.');
        }
        attempts.add(QuizTentativa.fromJson(rawAttempt));
      }

      if (!mounted) return;
      setState(() {
        _quizTitle = quizData['titulo'] as String? ?? 'Quiz';
        _videoTitle = quizData['video_titulo'] as String? ?? '';
        _questions = questions;
        _attempts = attempts;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _loadError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmSubmit() async {
    if (_isSubmitting) return;
    if (_questions.any((question) => !_answers.containsKey(question.id))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Responda todas as questões antes de enviar.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar quiz?'),
        content: const Text(
          'Sua nota será registrada no histórico. Você poderá refazer o quiz '
          'quantas vezes quiser; a nota mais recente ficará em destaque.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Revisar respostas'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar respostas'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _submitAnswers();
  }

  Future<void> _submitAnswers() async {
    setState(() => _isSubmitting = true);
    try {
      final response = await http
          .post(
            Uri.parse('$_quizBaseUrl/${widget.quizId}/tentativas'),
            headers: _headers,
            body: jsonEncode({
              'respostas': [
                for (final question in _questions)
                  {
                    'pergunta_id': question.id,
                    'resposta': _answers[question.id],
                  },
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));
      final data = decodeApiResponseObject(
        response.body,
        statusCode: response.statusCode,
        fallbackMessage: 'Não foi possível enviar o quiz.',
      );
      final rawAttempt = data['tentativa'];
      if (rawAttempt is! Map<String, dynamic>) {
        throw Exception('A API não retornou o resultado da tentativa.');
      }
      final attempt = QuizTentativa.fromJson(rawAttempt);
      if (!mounted) return;
      setState(() {
        _attempts = [attempt, ..._attempts];
        _hasSubmittedCurrentAnswers = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Quiz enviado. Sua nota foi ${_formatGrade(attempt.nota)}/10.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível enviar o quiz: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmRetry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refazer quiz?'),
        content: const Text(
          'As respostas selecionadas nesta tela serão apagadas. '
          'A nova nota será registrada sem remover as tentativas anteriores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Começar nova tentativa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _answers.clear();
      _hasSubmittedCurrentAnswers = false;
    });
  }

  Future<void> _confirmLeave() async {
    if (_isConfirmingLeave) return;
    _isConfirmingLeave = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do quiz?'),
        content: const Text(
          'As respostas que ainda não foram enviadas serão perdidas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar respondendo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    _isConfirmingLeave = false;
    if (confirmed == true && mounted) Navigator.of(context).pop();
  }

  String _formatGrade(double grade) =>
      grade.toStringAsFixed(2).replaceAll('.', ',');

  String _formatDateTime(BuildContext context, DateTime date) {
    final localDate = date.toLocal();
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(localDate)} às '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(localDate))}';
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_hasPendingAnswers,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _hasPendingAnswers) unawaited(_confirmLeave());
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('RESPONDER QUIZ')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.navy))
          : _loadError != null
          ? _LoadError(message: _loadError!, onRetry: _loadQuizAndHistory)
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: ListTile(
                          title: Text(
                            _quizTitle,
                            style: const TextStyle(
                              color: AppTheme.navy,
                              fontFamily: AppTheme.displayFontFamily,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: _videoTitle.isEmpty
                              ? null
                              : Text('Videoaula: $_videoTitle'),
                        ),
                      ),
                      _buildHistory(),
                      for (var index = 0; index < _questions.length; index++)
                        _buildQuestionCard(index),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting
                            ? null
                            : _hasSubmittedCurrentAnswers
                            ? _confirmRetry
                            : _confirmSubmit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.green,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _hasSubmittedCurrentAnswers
                                    ? 'Refazer quiz'
                                    : 'Enviar respostas',
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _buildHistory() {
    if (_attempts.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.history),
          title: Text('Você ainda não respondeu este quiz.'),
        ),
      );
    }

    final latest = _attempts.first;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.history, color: AppTheme.navy),
        title: Text(
          'Nota mais recente: ${_formatGrade(latest.nota)}/10',
          style: const TextStyle(
            color: AppTheme.navy,
            fontFamily: AppTheme.displayFontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${latest.acertos}/${latest.totalQuestoes} acertos · '
          '${_attempts.length} ${_attempts.length == 1 ? 'tentativa' : 'tentativas'}',
        ),
        children: [
          for (var index = 0; index < _attempts.length; index++)
            ListTile(
              dense: true,
              title: Text(
                'Tentativa ${_attempts.length - index} · '
                '${_formatDateTime(context, _attempts[index].realizadaEm)}',
              ),
              subtitle: Text(
                '${_attempts[index].acertos}/'
                '${_attempts[index].totalQuestoes} acertos',
              ),
              trailing: Text(
                '${_formatGrade(_attempts[index].nota)}/10',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final question = _questions[index];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Questão ${index + 1}: ${question.enunciado}',
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            RadioGroup<String>(
              groupValue: _answers[question.id],
              onChanged: (answer) {
                if (answer == null || _isSubmitting) return;
                setState(() {
                  _answers[question.id] = answer;
                  _hasSubmittedCurrentAnswers = false;
                });
              },
              child: Column(
                children: [
                  for (final alternative in question.alternativas)
                    RadioListTile<String>(
                      value: alternative,
                      title: Text(alternative),
                      enabled: !_isSubmitting,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizQuestion {
  const _QuizQuestion({
    required this.id,
    required this.enunciado,
    required this.alternativas,
  });

  final int id;
  final String enunciado;
  final List<String> alternativas;
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
