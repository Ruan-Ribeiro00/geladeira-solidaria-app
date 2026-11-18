import 'package:flutter/material.dart';

import '../data/repositorio.dart';
import '../services/auth_service.dart';
import '../tema.dart';

/// Tela 1 — Login. Formulário com `GlobalKey<FormState>`, validação e SnackBar.
class LoginScreen extends StatefulWidget {
  final AuthService? authService; // permite trocar o serviço nos testes

  const LoginScreen({super.key, this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _urlController = TextEditingController(text: Repositorio.instancia.urlApi);
  late final AuthService _auth = widget.authService ?? AuthService();

  bool _mostrarSenha = false;
  bool _carregando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String? _validarEmail(String? valor) {
    final email = (valor ?? '').trim();
    if (email.isEmpty) return 'Informe seu e-mail';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'E-mail inválido';
    return null;
  }

  String? _validarSenha(String? valor) {
    if ((valor ?? '').isEmpty) return 'Informe sua senha';
    if (valor!.length < 6) return 'A senha tem pelo menos 6 caracteres';
    return null;
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);
    final repo = Repositorio.instancia;
    repo.urlApi = _urlController.text.trim();
    final resultado = await _auth.login(repo.urlApi, _emailController.text, _senhaController.text);
    if (!mounted) return;
    setState(() => _carregando = false);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (!resultado.sucesso) {
      messenger.showSnackBar(SnackBar(
        content: Text(resultado.mensagem),
        backgroundColor: Cores.critico,
      ));
      return;
    }

    repo.usuario = resultado.usuario!;
    repo.conectadoNaApi = resultado.online;
    messenger.showSnackBar(SnackBar(
      content: Text('Olá, ${repo.usuario.nome}! ${resultado.mensagem}'),
      backgroundColor: resultado.online ? Cores.ok : Cores.atencao,
    ));
    Navigator.pushReplacementNamed(context, '/geladeiras');
  }

  void _entrarComoVisitante() {
    Repositorio.instancia.sair();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Você entrou como visitante: dá para ver as geladeiras, mas não doar.'),
    ));
    Navigator.pushReplacementNamed(context, '/geladeiras');
  }

  void _preencherTeste(String email) {
    setState(() {
      _emailController.text = email;
      _senhaController.text = AuthService.usuariosTeste[email]![0];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: LogoApp(tamanho: 88)),
                  const SizedBox(height: 16),
                  const Text(
                    'Geladeira Solidária',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Cores.verdeEscuro),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Comida boa não vai pro lixo, vai pra quem precisa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Cores.textoSuave),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    key: const Key('campoEmail'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: _validarEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('campoSenha'),
                    controller: _senhaController,
                    obscureText: !_mostrarSenha,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _entrar(),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _mostrarSenha ? 'Esconder senha' : 'Mostrar senha',
                        icon: Icon(_mostrarSenha ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                      ),
                    ),
                    validator: _validarSenha,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const Key('botaoEntrar'),
                    onPressed: _carregando ? null : _entrar,
                    child: _carregando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _carregando ? null : _entrarComoVisitante,
                    child: const Text('Só quero ver as geladeiras'),
                  ),
                  const SizedBox(height: 24),
                  const Text('Usuários de teste (os mesmos da API Java):',
                      style: TextStyle(color: Cores.textoSuave)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.volunteer_activism, size: 18),
                        label: const Text('Doador'),
                        onPressed: () => _preencherTeste('doador@geladeira.test'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.badge_outlined, size: 18),
                        label: const Text('Voluntário'),
                        onPressed: () => _preencherTeste('voluntario@geladeira.test'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                        label: const Text('Admin'),
                        onPressed: () => _preencherTeste('admin@geladeira.test'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    leading: const Icon(Icons.dns_outlined),
                    title: const Text('Servidor da API'),
                    children: [
                      TextFormField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Endereço da API Java',
                          helperText: 'Emulador: http://10.0.2.2:8080 · VM do Azure: http://IP:8080',
                        ),
                        validator: (v) => (v ?? '').trim().startsWith('http')
                            ? null
                            : 'Comece com http:// ou https://',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
