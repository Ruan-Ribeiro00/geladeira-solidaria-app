import 'package:flutter/material.dart';

import 'screens/alertas_screen.dart';
import 'screens/detalhe_geladeira_screen.dart';
import 'screens/geladeiras_screen.dart';
import 'screens/login_screen.dart';
import 'screens/nova_doacao_screen.dart';
import 'screens/perfil_screen.dart';
import 'services/auth_service.dart';
import 'tema.dart';

void main() {
  runApp(const GeladeiraSolidariaApp());
}

class GeladeiraSolidariaApp extends StatelessWidget {
  final AuthService? authService; // os testes trocam o serviço de login por um falso

  const GeladeiraSolidariaApp({super.key, this.authService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geladeira Solidária',
      debugShowCheckedModeBanner: false,
      theme: temaApp(),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(authService: authService),
        '/geladeiras': (context) => const GeladeirasScreen(),
        '/detalhe': (context) => const DetalheGeladeiraScreen(), // recebe o id da geladeira
        '/doacao': (context) => const NovaDoacaoScreen(), // recebe o id da geladeira
        '/alertas': (context) => const AlertasScreen(),
        '/perfil': (context) => const PerfilScreen(),
      },
    );
  }
}
