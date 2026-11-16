import 'package:flutter/material.dart';

import 'screens/geladeiras_screen.dart';
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
        '/': (context) => const GeladeirasScreen(),
        '/geladeiras': (context) => const GeladeirasScreen(),
      },
    );
  }
}
