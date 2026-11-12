import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class PerfilPage extends StatefulWidget {
  const PerfilPage({
    super.key,
    required this.accessToken,
    required this.profile,
    required this.onProfileUpdated,
    required this.onLoggedOut,
  });

  final String accessToken;
  final Map<String, dynamic> profile;
  final ValueChanged<Map<String, dynamic>> onProfileUpdated;
  final VoidCallback onLoggedOut;

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _schoolController = TextEditingController();
  final _roleDetailController = TextEditingController();
  final _subjectController = TextEditingController();

  late Map<String, dynamic> _profile;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoggingOut = false;

  bool get _isStudent => _profile['tipo_usuario'] == 'aluno';

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.profile);
    _fillControllers();
  }

  @override
  void didUpdateWidget(covariant PerfilPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _profile = Map<String, dynamic>.from(widget.profile);
      _fillControllers();
    }
  }

  @override
  void dispose() {
    _cpfController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _schoolController.dispose();
    _roleDetailController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  void _fillControllers() {
    _cpfController.text = '${_profile['cpf'] ?? ''}';
    _nameController.text = '${_profile['nome'] ?? ''}';
    _emailController.text = '${_profile['email'] ?? ''}';
    _schoolController.text = '${_profile['escola'] ?? ''}';
    _roleDetailController.text = _isStudent
        ? '${_profile['serie'] ?? ''}'
        : '${_profile['cndb'] ?? ''}';
    _subjectController.text = '${_profile['materia'] ?? ''}';
  }

  void _cancelEditing() {
    setState(() {
      _fillControllers();
      _isEditing = false;
    });
  }

  Future<void> _confirmAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar alterações'),
        content: const Text(
          'Deseja realmente alterar as informações do seu perfil?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF01D0AF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _saveProfile();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final updatedProfile = <String, dynamic>{
      ..._profile,
      'tipo_usuario': _profile['tipo_usuario'],
      'cpf': _cpfController.text.trim(),
      'nome': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'escola': _schoolController.text.trim(),
      if (_isStudent)
        'serie': _roleDetailController.text.trim()
      else
          ...{
            'cndb': _roleDetailController.text.trim(),
            'materia': _subjectController.text.trim(),
          },
    };

    try {
      final response = await http
          .patch(
            Uri.parse('http://localhost:8080/api/users/${_profile['id']}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.accessToken}',
            },
            body: jsonEncode(updatedProfile),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 204) {
        final decoded = response.body.isEmpty
            ? null
            : jsonDecode(response.body);
        final data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        throw Exception(
          data['message'] ?? 'Não foi possível salvar as alterações.',
        );
      }

      if (!mounted) return;
      setState(() {
        _profile = updatedProfile;
        _isEditing = false;
      });
      widget.onProfileUpdated(Map<String, dynamic>.from(updatedProfile));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao atualizar perfil: $message')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar saída'),
        content: const Text('Deseja realmente sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sair da conta'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _logout();
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      final response = await http
          .post(
            Uri.parse('http://localhost:8080/api/users/logout'),
            headers: {'Authorization': 'Bearer ${widget.accessToken}'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        final decoded = response.body.isEmpty
            ? null
            : jsonDecode(response.body);
        final data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{};
        throw Exception(
          data['message'] ?? 'Não foi possível encerrar a sessão.',
        );
      }

      if (mounted) widget.onLoggedOut();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao sair: $message')));
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Widget _profileField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? labelAction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 18, color: Colors.black),
              ),
              ?labelAction,
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: _isEditing && !_isSaving,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFD9D9D9),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = _isStudent ? 'ALUNO' : 'PROFESSOR';

    return Container(
      color: const Color(0xFFB9E1DB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Text(
                  'PERFIL - $roleLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _profileField(
                            label: 'CPF',
                            controller: _cpfController,
                            labelAction: IconButton(
                              onPressed: _isEditing || _isSaving
                                  ? null
                                  : () => setState(() => _isEditing = true),
                              tooltip: 'Editar perfil',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            validator: (value) =>
                                value == null || value.length != 11
                                ? 'Digite os 11 números do CPF.'
                                : null,
                          ),
                          _profileField(
                            label: 'Nome completo',
                            controller: _nameController,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Digite seu nome completo.'
                                : null,
                          ),
                          _profileField(
                            label: 'Email',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(email)
                                  ? null
                                  : 'Digite um email válido.';
                            },
                          ),
                          _profileField(
                            label: 'Escola',
                            controller: _schoolController,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Digite o nome da sua escola.'
                                : null,
                          ),
                          _profileField(
                            label: _isStudent ? 'Série' : 'CNDB',
                            controller: _roleDetailController,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? _isStudent
                                      ? 'Digite sua série/ano.'
                                      : 'Digite seu código CNDB.'
                                : null,
                          ),
                          if (!_isStudent)
                            _profileField(
                              label: 'Matéria',
                              controller: _subjectController,
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Digite a matéria que leciona.'
                                  : null,
                            ),
                          if (_isEditing) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isSaving
                                        ? null
                                        : _cancelEditing,
                                    child: const Text('Cancelar'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _isSaving
                                        ? null
                                        : _confirmAndSave,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF01D0AF),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Salvar'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: _isLoggingOut
                                  ? null
                                  : _confirmAndLogout,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _isLoggingOut
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Sair da conta'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
