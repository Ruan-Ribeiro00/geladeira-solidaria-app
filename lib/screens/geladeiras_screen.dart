import 'package:flutter/material.dart';

import '../data/repositorio.dart';
import '../models/modelos.dart';
import '../tema.dart';
import '../widgets/componentes.dart';

enum FiltroGeladeiras { todas, favoritas, precisamDoacao, comEspaco }

/// Tela 2 — Lista de geladeiras com busca por bairro, filtros e favoritas (setState).
class GeladeirasScreen extends StatefulWidget {
  const GeladeirasScreen({super.key});

  @override
  State<GeladeirasScreen> createState() => _GeladeirasScreenState();
}

class _GeladeirasScreenState extends State<GeladeirasScreen> {
  final repo = Repositorio.instancia;
  String _busca = '';
  FiltroGeladeiras _filtro = FiltroGeladeiras.todas;

  List<Geladeira> get _filtradas {
    final busca = _busca.trim().toLowerCase();
    return repo.geladeiras.where((g) {
      final textoOk = busca.isEmpty ||
          g.bairro.toLowerCase().contains(busca) ||
          g.nome.toLowerCase().contains(busca);
      if (!textoOk) return false;
      switch (_filtro) {
        case FiltroGeladeiras.todas:
          return true;
        case FiltroGeladeiras.favoritas:
          return repo.favoritas.contains(g.id);
        case FiltroGeladeiras.precisamDoacao:
          return g.status == StatusGeladeira.ativa && repo.ocupacaoPct(g) <= 0.4;
        case FiltroGeladeiras.comEspaco:
          return g.status == StatusGeladeira.ativa && repo.livreKg(g) >= 20;
      }
    }).toList();
  }

  Future<void> _abrirDetalhe(Geladeira g) async {
    // Passa o id da geladeira como parâmetro da rota
    await Navigator.pushNamed(context, '/detalhe', arguments: g.id);
    setState(() {}); // volta da tela de detalhe: atualiza ocupação e favoritas
  }

  void _alternarFavorita(Geladeira g) {
    setState(() => repo.alternarFavorita(g.id));
    final favorita = repo.favoritas.contains(g.id);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(favorita ? '${g.bairro} adicionada às favoritas' : '${g.bairro} removida das favoritas'),
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _chip(String texto, FiltroGeladeiras filtro, IconData icone) {
    final selecionado = _filtro == filtro;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icone, size: 18, color: selecionado ? Colors.white : Cores.verde),
        label: Text(texto),
        selected: selecionado,
        showCheckmark: false,
        selectedColor: Cores.verde,
        labelStyle: TextStyle(color: selecionado ? Colors.white : Cores.texto),
        onSelected: (_) => setState(() => _filtro = filtro),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtradas;
    final ativas = repo.geladeiras.where((g) => g.status == StatusGeladeira.ativa).length;
    final kgDisponiveis = repo.geladeiras.fold(0.0, (soma, g) => soma + repo.ocupacaoKg(g));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geladeiras'),
        actions: [
          if (repo.usuario.operaGeladeiras)
            IconButton(
              tooltip: 'Alertas',
              icon: Badge(
                isLabelVisible: repo.alertasAbertos > 0,
                label: Text('${repo.alertasAbertos}'),
                backgroundColor: Cores.laranja,
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => Navigator.pushReplacementNamed(context, '/alertas'),
            ),
        ],
      ),
      drawer: const MenuLateral(rotaAtual: '/geladeiras'),
      body: Column(
        children: [
          Container(
            color: Cores.verde,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$ativas geladeiras ativas · ${kgDisponiveis.toStringAsFixed(0)} kg de alimentos disponíveis',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('campoBusca'),
                  onChanged: (texto) => setState(() => _busca = texto),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por bairro (ex.: Itaquera)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _chip('Todas', FiltroGeladeiras.todas, Icons.apps),
                _chip('Favoritas (${repo.favoritas.length})', FiltroGeladeiras.favoritas, Icons.star),
                _chip('Precisam de doação', FiltroGeladeiras.precisamDoacao, Icons.volunteer_activism),
                _chip('Com espaço', FiltroGeladeiras.comEspaco, Icons.inventory_2_outlined),
              ],
            ),
          ),
          Expanded(
            child: lista.isEmpty
                ? ListView(children: const [
                    ListaVazia(icone: Icons.search_off, texto: 'Nenhuma geladeira encontrada com esse filtro.'),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: lista.length,
                    itemBuilder: (context, i) => _cartao(lista[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cartao(Geladeira g) {
    final situacao = repo.situacao(g);
    final favorita = repo.favoritas.contains(g.id);
    final ocupado = repo.ocupacaoKg(g);

    return Card(
      key: Key('geladeira-${g.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrirDetalhe(g),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.bairro,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Cores.texto)),
                        const SizedBox(height: 2),
                        Text('${g.endereco} · ${g.horario}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Cores.textoSuave, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    key: Key('favorita-${g.id}'),
                    tooltip: favorita ? 'Remover das favoritas' : 'Favoritar',
                    icon: Icon(favorita ? Icons.star : Icons.star_border,
                        color: favorita ? Cores.laranja : Cores.neutro),
                    onPressed: () => _alternarFavorita(g),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Etiqueta(texto: situacao.texto, cor: situacao.cor, icone: situacao.icone),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.thermostat, size: 16, color: Cores.textoSuave),
                        Text(' ${dec(g.temperaturaC)} °C',
                            style: const TextStyle(color: Cores.textoSuave)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    BarraOcupacao(pct: repo.ocupacaoPct(g)),
                    const SizedBox(height: 4),
                    Text(
                      '${ocupado.toStringAsFixed(0)} de ${g.capacidadeKg.toStringAsFixed(0)} kg · '
                      '${repo.livreKg(g).toStringAsFixed(0)} kg livres',
                      style: const TextStyle(fontSize: 12, color: Cores.textoSuave),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
