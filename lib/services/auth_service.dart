import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/modelos.dart';

/// Resultado de uma tentativa de login.
class ResultadoLogin {
  final Usuario? usuario;
  final bool online; // true = token veio da API Java; false = modo offline
  final String mensagem;

  const ResultadoLogin({this.usuario, required this.online, required this.mensagem});

  bool get sucesso => usuario != null;
}

/// Login na API Java (`POST /auth/login`, devolve o JWT).
///
/// Se a API estiver fora do ar, o app ainda deixa entrar com os mesmos usuários
/// de teste da API (modo offline), para a demonstração não depender do servidor.
class AuthService {
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  /// Os mesmos usuários de teste do README da API Java.
  static const usuariosTeste = {
    'doador@geladeira.test': ['Doador@123', 'Doador Teste', 'DOADOR'],
    'voluntario@geladeira.test': ['Voluntario@123', 'Voluntário Teste', 'VOLUNTARIO'],
    'admin@geladeira.test': ['Admin@123', 'Administrador', 'ADMIN'],
  };

  Future<ResultadoLogin> login(String urlApi, String email, String senha) async {
    final emailLimpo = email.trim().toLowerCase();
    try {
      final resposta = await _client
          .post(
            Uri.parse('$urlApi/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': emailLimpo, 'senha': senha}),
          )
          .timeout(const Duration(seconds: 5));

      if (resposta.statusCode == 200) {
        final json = jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
        final dados = (json['usuario'] as Map<String, dynamic>?) ?? {};
        final papel = Usuario.papelDaApi(dados['papel'] as String?);
        if (papel == Papel.visitante) {
          return const ResultadoLogin(
              online: true, mensagem: 'Esta conta é de um sensor IoT e não usa o app.');
        }
        return ResultadoLogin(
          online: true,
          mensagem: 'Login feito na API Java.',
          usuario: Usuario(
            nome: (dados['nome'] as String?) ?? emailLimpo,
            email: emailLimpo,
            papel: papel,
            token: json['token'] as String?,
          ),
        );
      }
      if (resposta.statusCode == 401 || resposta.statusCode == 400) {
        return const ResultadoLogin(online: true, mensagem: 'E-mail ou senha incorretos.');
      }
      return _offline(emailLimpo, senha, 'A API respondeu ${resposta.statusCode}.');
    } on TimeoutException {
      return _offline(emailLimpo, senha, 'A API não respondeu.');
    } catch (_) {
      return _offline(emailLimpo, senha, 'Não consegui falar com a API.');
    }
  }

  ResultadoLogin _offline(String email, String senha, String motivo) {
    final teste = usuariosTeste[email];
    if (teste != null && teste[0] == senha) {
      return ResultadoLogin(
        online: false,
        mensagem: '$motivo Entrei em modo offline.',
        usuario: Usuario(nome: teste[1], email: email, papel: Usuario.papelDaApi(teste[2])),
      );
    }
    return ResultadoLogin(
      online: false,
      mensagem: '$motivo Sem a API, só os usuários de teste entram.',
    );
  }
}
