import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class CadastroAlunoPage extends StatefulWidget {
  const CadastroAlunoPage({super.key});

  @override
  State<CadastroAlunoPage> createState() => _CadastroAlunoPageState();
}

class _CadastroAlunoPageState extends State<CadastroAlunoPage> {
  static const String cadastroUrl = 'http://localhost:8080/api/users/cadastrar';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _emailController = TextEditingController();
  final _schoolController = TextEditingController();
  final _gradeController = TextEditingController();
  final _subjectController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedCategory;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _cpfController.dispose();
    _emailController.dispose();
    _schoolController.dispose();
    _gradeController.dispose();
    _subjectController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    final category = _selectedCategory;
    if (category == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await http
          .post(
            Uri.parse(cadastroUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'tipo_usuario': category,
              'nome': _nameController.text.trim(),
              'cpf': _cpfController.text.trim(),
              'email': _emailController.text.trim(),
              'escola': _schoolController.text.trim(),
              if (category == 'aluno')
                'serie': _gradeController.text.trim()
              else ...{
                'cndb': _gradeController.text.trim(),
                'materia': _subjectController.text.trim(),
              },
              'senha': _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      if (response.statusCode != 201) {
        throw Exception(data['message'] ?? 'Não foi possível criar a conta.');
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha no cadastro: $message')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFD9D9D9),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    ),
  );

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 20, color: Colors.black)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          decoration: _inputDecoration(hint).copyWith(suffixIcon: suffixIcon),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildCommonFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          label: 'CPF',
          hint: 'Insira seu CPF',
          controller: _cpfController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          validator: (value) => value == null || value.length != 11
              ? 'Digite os 11 números do CPF.'
              : null,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'Nome completo',
          hint: 'Insira seu nome completo',
          controller: _nameController,
          textInputAction: TextInputAction.next,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Digite seu nome completo.'
              : null,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'Email',
          hint: 'Insira seu email',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final email = value?.trim() ?? '';
            return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                ? null
                : 'Digite um email válido.';
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRoleFields() {
    final isStudent = _selectedCategory == 'aluno';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          label: 'Escola',
          hint: 'Insira o nome da sua escola',
          controller: _schoolController,
          textInputAction: TextInputAction.next,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Digite o nome da sua escola.'
              : null,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: isStudent ? 'Série' : 'CNDB',
          hint: isStudent ? 'Ex.: 8º EF, 1º EM' : 'Insira seu código CNDB',
          controller: _gradeController,
          textInputAction: TextInputAction.next,
          inputFormatters: isStudent
              ? [LengthLimitingTextInputFormatter(10)]
              : null,
          validator: (value) => value == null || value.trim().isEmpty
              ? isStudent
                    ? 'Digite sua série/ano.'
                    : 'Digite seu código CNDB.'
              : null,
        ),
        const SizedBox(height: 20),
        if (!isStudent) ...[
          _buildTextField(
            label: 'Matéria',
            hint: 'Insira a matéria que leciona',
            controller: _subjectController,
            textInputAction: TextInputAction.next,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Digite a matéria que leciona.'
                : null,
          ),
          const SizedBox(height: 20),
        ],
        _buildTextField(
          label: 'Crie uma senha',
          hint: 'Insira sua senha',
          controller: _passwordController,
          textInputAction: TextInputAction.next,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          validator: (value) => value == null || value.length < 8
              ? 'A senha deve ter pelo menos 8 caracteres.'
              : null,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'Confirme sua senha',
          hint: 'Insira sua senha novamente',
          controller: _confirmPasswordController,
          textInputAction: TextInputAction.done,
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            tooltip: _obscureConfirmPassword
                ? 'Mostrar senha'
                : 'Ocultar senha',
            onPressed: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          validator: (value) => value != _passwordController.text
              ? 'As senhas não conferem.'
              : null,
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 53,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submitRegistration,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF01D0AF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Criar conta', style: TextStyle(fontSize: 20)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 289,
              color: const Color(0xFF0D1F43),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset(
                    'lib/application/icons/prisma_logo.png',
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'CADASTRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCommonFields(),
                        const SizedBox(height: 24),
                        const Text(
                          'Qual categoria você se enquadra?',
                          style: TextStyle(fontSize: 20, color: Colors.black),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          emptySelectionAllowed: true,
                          segments: const [
                            ButtonSegment(
                              value: 'aluno',
                              label: Text('Sou Aluno'),
                              icon: Icon(Icons.school_outlined),
                            ),
                            ButtonSegment(
                              value: 'professor',
                              label: Text('Sou Professor'),
                              icon: Icon(Icons.cast_for_education_outlined),
                            ),
                          ],
                          selected: _selectedCategory == null
                              ? <String>{}
                              : <String>{_selectedCategory!},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _selectedCategory = selection.isEmpty
                                  ? null
                                  : selection.first;
                              _gradeController.clear();
                              _subjectController.clear();
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: const Color(0xFF01D0AF),
                            selectedForegroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0D1F43),
                          ),
                        ),
                        if (_selectedCategory != null) ...[
                          const SizedBox(height: 24),
                          _buildRoleFields(),
                        ],
                        const SizedBox(height: 24),
                        Center(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('Já tem uma conta? '),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: Colors.black,
                                  textStyle: const TextStyle(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                child: const Text('Entrar'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
