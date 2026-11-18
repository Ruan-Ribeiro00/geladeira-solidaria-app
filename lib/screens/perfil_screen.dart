import 'package:flutter/material.dart';

import '../data/repositorio.dart';
import '../models/modelos.dart';
import '../tema.dart';
import '../widgets/componentes.dart';

/// Tela 6 — Perfil, impacto da rede e os ODS que o projeto atende.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  static const _ods = [
    [2, 'Fome zero e agricultura sustentável', 'Leva comida a quem está em insegurança alimentar.', 0xFFDDA63A],
    [3, 'Saúde e bem-estar', 'O sensor de temperatura e o controle de validade evitam alimento estragado.', 0xFF4C9F38],
    [10, 'Redução das desigualdades', 'As geladeiras ficam nas periferias, onde a fome é maior.', 0xFFDD1367],
    [11, 'Cidades e comunidades sustentáveis', 'Rede comunitária gerida por moradores e voluntários.', 0xFFFD9D24],
    [12, 'Consumo e produção responsáveis', 'Comida que iria para o lixo vira doação.', 0xFFBF8B2E],
  ];

  @override
  Widget build(BuildContext context) {
    final repo = Repositorio.instancia;
    final usuario = repo.usuario;
    final ativas = repo.geladeiras.where((g) => g.status == StatusGeladeira.ativa).length;
    final kg = repo.geladeiras.fold(0.0, (soma, g) => soma + repo.ocupacaoKg(g));
    final emRisco = repo.doacoes
        .where((d) => !d.retirada && repo.risco(d) != NivelRisco.ok)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil e impacto')),
      drawer: const MenuLateral(rotaAtual: '/perfil'),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Cores.laranjaClaro,
                child: Text(
                  usuario.nome.isEmpty ? '?' : usuario.nome[0].toUpperCase(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Cores.laranja),
                ),
              ),
              title: Text(usuario.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (usuario.email.isNotEmpty) Text(usuario.email),
                  const SizedBox(height: 6),
                  Etiqueta(texto: nomePapel(usuario.papel), cor: Cores.verde, icone: Icons.badge_outlined),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                repo.conectadoNaApi ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: repo.conectadoNaApi ? Cores.ok : Cores.atencao,
              ),
              title: Text(repo.conectadoNaApi ? 'Conectado à API Java' : 'Modo offline (dados de exemplo)'),
              subtitle: Text(repo.conectadoNaApi
                  ? '${repo.urlApi} · token JWT recebido'
                  : 'O login não passou pela API. Os dados são os mesmos da carga inicial da API.'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Impacto da rede', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _numero('$ativas', 'geladeiras\nativas', Icons.kitchen_outlined),
                _numero(kg.toStringAsFixed(0), 'kg de comida\ndisponível', Icons.scale_outlined),
                _numero('$emRisco', 'alimentos\npara priorizar', Icons.priority_high),
                _numero('${repo.doacoesNaSessao}', 'doações\nfeitas por você', Icons.volunteer_activism),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Objetivos de Desenvolvimento Sustentável (ONU)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ..._ods.map((o) => Card(
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color(o[3] as int),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${o[0]}',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('ODS ${o[0]} · ${o[1]}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(o[2] as String),
                ),
              )),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Text(
              'Geladeira Solidária Inteligente · Global Solution 2026/2 (CitizenTech) · FIAP\n'
              'Ruan Ribeiro · RM 567693 · 2TDSPA',
              textAlign: TextAlign.center,
              style: TextStyle(color: Cores.textoSuave, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numero(String valor, String rotulo, IconData icone) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            children: [
              Icon(icone, color: Cores.laranja),
              const SizedBox(height: 6),
              Text(valor,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Cores.verdeEscuro)),
              Text(rotulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Cores.textoSuave)),
            ],
          ),
        ),
      ),
    );
  }
}
