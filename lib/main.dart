import 'package:flutter/material.dart';

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
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LogoApp(tamanho: 96),
              SizedBox(height: 16),
              Text(
                'Geladeira Solidária',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Cores.verdeEscuro),
              ),
              SizedBox(height: 4),
              Text('Comida boa não vai pro lixo, vai pra quem precisa.',
                  style: TextStyle(color: Cores.textoSuave)),
            ],
          ),
        ),
      ),
    );
  }
}
