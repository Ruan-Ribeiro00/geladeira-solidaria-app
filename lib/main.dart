import 'package:flutter/material.dart';

import 'screens/detalhe_geladeira_screen.dart';
import 'screens/geladeiras_screen.dart';
import 'screens/login_screen.dart';
import 'screens/nova_doacao_screen.dart';
import 'tema.dart';

void main() {
  runApp(const GeladeiraSolidariaApp());
}

class GeladeiraSolidariaApp extends StatelessWidget {
  const GeladeiraSolidariaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geladeira Solidária',
      debugShowCheckedModeBanner: false,
      theme: temaApp(),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/geladeiras': (context) => const GeladeirasScreen(),
        '/detalhe': (context) => const DetalheGeladeiraScreen(), // recebe o id da geladeira
        '/doacao': (context) => const NovaDoacaoScreen(), // recebe o id da geladeira
      },
    );
  }
}
