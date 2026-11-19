import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geladeira_solidaria/data/repositorio.dart';
import 'package:geladeira_solidaria/main.dart';
import 'package:geladeira_solidaria/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Testes de interface: navegam pelo app como um usuário faria.
void main() {
  final repo = Repositorio.instancia;

  // API Java falsa: aceita o voluntário e recusa o resto
  final apiOnline = MockClient((req) async {
    final corpo = jsonDecode(req.body) as Map<String, dynamic>;
    if (req.url.path == '/auth/login' &&
        corpo['email'] == 'voluntario@geladeira.test' &&
        corpo['senha'] == 'Voluntario@123') {
      return http.Response(
        jsonEncode({
          'token': 'jwt-de-teste',
          'usuario': {'nome': 'Vera Voluntária', 'papel': 'VOLUNTARIO'},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response('{"status":401}', 401);
  });

  // API fora do ar
  final apiFora = MockClient((req) async => throw const SocketException('Connection refused'));

  Future<void> abrirApp(WidgetTester tester, http.Client client) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GeladeiraSolidariaApp(authService: AuthService(client: client)));
  }

  Future<void> entrar(WidgetTester tester, String email, String senha) async {
    await tester.enterText(find.byKey(const Key('campoEmail')), email);
    await tester.enterText(find.byKey(const Key('campoSenha')), senha);
    await tester.tap(find.byKey(const Key('botaoEntrar')));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo.reiniciar();
    repo.sair();
  });

  testWidgets('login valida os campos antes de chamar a API', (tester) async {
    await abrirApp(tester, apiOnline);
    await tester.tap(find.byKey(const Key('botaoEntrar')));
    await tester.pump();
    expect(find.text('Informe seu e-mail'), findsOneWidget);
    expect(find.text('Informe sua senha'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campoEmail')), 'sem-arroba');
    await tester.enterText(find.byKey(const Key('campoSenha')), '123');
    await tester.tap(find.byKey(const Key('botaoEntrar')));
    await tester.pump();
    expect(find.text('E-mail inválido'), findsOneWidget);
    expect(find.text('A senha tem pelo menos 6 caracteres'), findsOneWidget);
  });

  testWidgets('login na API Java guarda o token e abre a lista', (tester) async {
    await abrirApp(tester, apiOnline);
    await entrar(tester, 'voluntario@geladeira.test', 'Voluntario@123');
    expect(find.text('Geladeiras'), findsWidgets);
    expect(repo.conectadoNaApi, isTrue);
    expect(repo.usuario.token, 'jwt-de-teste');
    expect(repo.usuario.nome, 'Vera Voluntária');
  });

  testWidgets('senha errada mostra SnackBar e continua no login', (tester) async {
    await abrirApp(tester, apiOnline);
    await entrar(tester, 'voluntario@geladeira.test', 'Errada@123');
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(find.byKey(const Key('botaoEntrar')), findsOneWidget);
  });

  testWidgets('com a API fora do ar, usuário de teste entra em modo offline', (tester) async {
    await abrirApp(tester, apiFora);
    await entrar(tester, 'doador@geladeira.test', 'Doador@123');
    expect(find.textContaining('modo offline'), findsOneWidget);
    expect(repo.conectadoNaApi, isFalse);
    expect(find.byKey(const Key('geladeira-1')), findsOneWidget);
  });

  testWidgets('busca por bairro, favoritar e filtro de favoritas', (tester) async {
    await abrirApp(tester, apiFora);
    await tester.tap(find.text('Só quero ver as geladeiras'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('campoBusca')), 'itaq');
    await tester.pump();
    expect(find.byKey(const Key('geladeira-7')), findsOneWidget);
    expect(find.byKey(const Key('geladeira-1')), findsNothing);

    await tester.tap(find.byKey(const Key('favorita-7')));
    await tester.pump();
    expect(repo.favoritas, contains(7));

    await tester.enterText(find.byKey(const Key('campoBusca')), '');
    await tester.tap(find.text('Favoritas (1)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('geladeira-7')), findsOneWidget);
    expect(find.byKey(const Key('geladeira-2')), findsNothing);
  });

  testWidgets('detalhe recebe o id pela rota e visitante não consegue doar', (tester) async {
    await abrirApp(tester, apiFora);
    await tester.tap(find.text('Só quero ver as geladeiras'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('geladeira-2')));
    await tester.pumpAndSettle();
    expect(find.text('Geladeira Solidária Heliópolis'), findsOneWidget);
    expect(find.text('Temperatura alta'), findsOneWidget);
    expect(find.text('Leite integral'), findsOneWidget);

    await tester.tap(find.byKey(const Key('botaoDoar')));
    await tester.pumpAndSettle();
    expect(find.text('Entre com sua conta para registrar uma doação.'), findsOneWidget);
  });

  testWidgets('registrar doação: valida, conta volumes e atualiza a geladeira', (tester) async {
    await abrirApp(tester, apiFora);
    await entrar(tester, 'doador@geladeira.test', 'Doador@123');

    await tester.enterText(find.byKey(const Key('campoBusca')), 'itaquera');
    await tester.pump();
    await tester.tap(find.byKey(const Key('geladeira-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('botaoDoar')));
    await tester.pumpAndSettle();
    expect(find.text('Registrar doação'), findsWidgets);

    // envia vazio: mostra os erros do formulário
    await tester.tap(find.byKey(const Key('botaoRegistrar')));
    await tester.pumpAndSettle();
    expect(find.text('Escolha a categoria'), findsOneWidget);
    expect(find.text('Descreva o alimento'), findsOneWidget);

    // preenche
    await tester.tap(find.byKey(const Key('campoCategoria')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frutas').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campoDescricao')), 'Peras');
    await tester.enterText(find.byKey(const Key('campoQuantidade')), '4,5');
    await tester.tap(find.byKey(const Key('campoValidade')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // contador de volumes (setState)
    await tester.tap(find.byKey(const Key('maisVolume')));
    await tester.tap(find.byKey(const Key('maisVolume')));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('checkDeclaracao')));
    await tester.tap(find.byKey(const Key('checkDeclaracao')));
    await tester.ensureVisible(find.byKey(const Key('botaoRegistrar')));
    await tester.tap(find.byKey(const Key('botaoRegistrar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Doação registrada!'), findsOneWidget);
    expect(find.text('Peras'), findsOneWidget); // voltou ao detalhe com o alimento novo
    final peras = repo.doacoes.firstWhere((d) => d.descricao == 'Peras');
    expect(peras.quantidadeKg, 4.5);
    expect(peras.volumes, 3);
    expect(peras.doador, 'Doador Teste');
  });

  testWidgets('doação que não cabe mostra a sugestão de outra geladeira', (tester) async {
    await abrirApp(tester, apiFora);
    await entrar(tester, 'doador@geladeira.test', 'Doador@123');

    await tester.tap(find.byKey(const Key('geladeira-1'))); // Capão Redondo, 1 kg livre
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('botaoDoar')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('campoCategoria')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grãos e cereais').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campoDescricao')), 'Arroz');
    await tester.enterText(find.byKey(const Key('campoQuantidade')), '5');
    await tester.tap(find.byKey(const Key('campoValidade')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('checkDeclaracao')));
    await tester.tap(find.byKey(const Key('checkDeclaracao')));
    await tester.ensureVisible(find.byKey(const Key('botaoRegistrar')));
    await tester.tap(find.byKey(const Key('botaoRegistrar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não cabe'), findsOneWidget);
    await tester.tap(find.text('Usar Itaquera'));
    await tester.pumpAndSettle();
    expect(find.text('Itaquera'), findsOneWidget); // geladeira trocada no formulário
  });

  testWidgets('voluntário resolve um alerta', (tester) async {
    await abrirApp(tester, apiOnline);
    await entrar(tester, 'voluntario@geladeira.test', 'Voluntario@123');

    await tester.tap(find.byTooltip('Alertas'));
    await tester.pumpAndSettle();
    final abertosAntes = repo.alertasAbertos;
    expect(find.byKey(const Key('alerta-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('resolver-1')));
    await tester.pumpAndSettle();
    expect(repo.alertasAbertos, abertosAntes - 1);
    expect(find.byKey(const Key('alerta-1')), findsNothing);

    await tester.tap(find.byKey(const Key('switchResolvidos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alerta-1')), findsOneWidget);
  });

  testWidgets('menu lateral leva ao perfil com os ODS', (tester) async {
    await abrirApp(tester, apiFora);
    await entrar(tester, 'doador@geladeira.test', 'Doador@123');

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Alertas'), findsNothing); // doador não vê alertas
    await tester.tap(find.text('Perfil e impacto'));
    await tester.pumpAndSettle();
    expect(find.text('Modo offline (dados de exemplo)'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('ODS 2'), 200);
    expect(find.textContaining('Fome zero'), findsOneWidget);
  });
}
