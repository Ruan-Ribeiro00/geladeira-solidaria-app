import 'package:flutter/material.dart';

import '../data/repositorio.dart';
import '../models/modelos.dart';
import '../tema.dart';
import '../widgets/componentes.dart';

/// Tela 3 — Detalhe da geladeira. Recebe o id da geladeira como parâmetro da rota:
/// `Navigator.pushNamed(context, '/detalhe', arguments: geladeira.id)`.
class DetalheGeladeiraScreen extends StatefulWidget {
  const DetalheGeladeiraScreen({super.key});

  @override
  State<DetalheGeladeiraScreen> createState() => _DetalheGeladeiraScreenState();
}

class _DetalheGeladeiraScreenState extends State<DetalheGeladeiraScreen> {
  final repo = Repositorio.instancia;

  Future<void> _doar(Geladeira g) async {
    if (!repo.usuario.podeDoar) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Entre com sua conta para registrar uma doação.'),
        action: SnackBarAction(
          label: 'Entrar',
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (rota) => false),
        ),
      ));
      return;
    }
    final registrou = await Navigator.pushNamed(context, '/doacao', arguments: g.id);
    if (registrou == true) setState(() {});
  }

  void _marcarRetirada(Doacao d) {
    setState(() => repo.marcarRetirada(d, true));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${d.descricao} marcado como retirado.'),
      action: SnackBarAction(
        label: 'Desfazer',
        onPressed: () => setState(() => repo.marcarRetirada(d, false)),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)!.settings.arguments as int;
    final g = repo.geladeira(id);
    final situacao = repo.situacao(g);
    final favorita = repo.favoritas.contains(g.id);
    final alimentos = repo.doacoesDisponiveis(g.id);
    final pct = repo.ocupacaoPct(g);
    final ativa = g.status == StatusGeladeira.ativa;

    return Scaffold(
      appBar: AppBar(
        title: Text(g.bairro),
        actions: [
          IconButton(
            key: const Key('favoritaDetalhe'),
            tooltip: favorita ? 'Remover das favoritas' : 'Favoritar',
            icon: Icon(favorita ? Icons.star : Icons.star_border, color: favorita ? Cores.laranja : null),
            onPressed: () => setState(() => repo.alternarFavorita(g.id)),
          ),
        ],
      ),
      floatingActionButton: ativa
          ? FloatingActionButton.extended(
              key: const Key('botaoDoar'),
              onPressed: () => _doar(g),
              icon: const Icon(Icons.add),
              label: const Text('Doar aqui'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        children: [
          // ------------------------------------------------ identificação
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _linha(Icons.place_outlined, '${g.endereco} · ${g.bairro}, São Paulo'),
                  _linha(Icons.schedule, 'Funciona: ${g.horario}'),
                  _linha(Icons.groups_outlined, 'Responsável: ${g.responsavel}'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Etiqueta(texto: situacao.texto, cor: situacao.cor, icone: situacao.icone),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(situacao.detalhe, style: const TextStyle(color: Cores.textoSuave)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ------------------------------------------------ sensor IoT
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sensor da geladeira', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _medida(Icons.thermostat, '${dec(g.temperaturaC)} °C', 'Temperatura',
                          g.temperaturaC > Regras.tempMaxGeral ? Cores.critico : Cores.ok),
                      _medida(Icons.water_drop_outlined, '${g.umidadePct.toStringAsFixed(0)}%', 'Umidade',
                          Cores.verde),
                      _medida(g.portaAberta ? Icons.door_front_door : Icons.door_front_door_outlined,
                          g.portaAberta ? 'Aberta' : 'Fechada', 'Porta',
                          g.portaAberta ? Cores.atencao : Cores.ok),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Última leitura ${tempoAtras(g.ultimaLeitura)} · ESP32 via MQTT',
                    style: TextStyle(
                      fontSize: 12,
                      color: repo.sensorOffline(g) ? Cores.critico : Cores.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ------------------------------------------------ ocupação
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Ocupação', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('${(pct * 100).round()}%',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Cores.verdeEscuro)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BarraOcupacao(pct: pct, altura: 12),
                  const SizedBox(height: 6),
                  Text(
                    '${dec(repo.ocupacaoKg(g))} de ${g.capacidadeKg.toStringAsFixed(0)} kg · '
                    'cabem mais ${dec(repo.livreKg(g))} kg',
                    style: const TextStyle(color: Cores.textoSuave),
                  ),
                ],
              ),
            ),
          ),
          // ------------------------------------------------ alimentos
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Alimentos disponíveis (${alimentos.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (alimentos.isEmpty)
            const ListaVazia(icone: Icons.no_food_outlined, texto: 'Esta geladeira está vazia. Que tal doar?'),
          ...alimentos.map(_itemAlimento),
        ],
      ),
    );
  }

  Widget _linha(IconData icone, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: Cores.verde),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }

  Widget _medida(IconData icone, String valor, String rotulo, Color cor) {
    return Expanded(
      child: Column(
        children: [
          Icon(icone, color: cor, size: 28),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(fontWeight: FontWeight.bold, color: cor)),
          Text(rotulo, style: const TextStyle(fontSize: 12, color: Cores.textoSuave)),
        ],
      ),
    );
  }

  Widget _itemAlimento(Doacao d) {
    final risco = repo.risco(d);
    return Card(
      key: Key('alimento-${d.id}'),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Cores.verdeClaro,
          child: Icon(d.categoria.icone, color: Cores.verde),
        ),
        title: Text(d.descricao, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${dec(d.quantidadeKg)} kg · ${d.volumes} '
                  '${d.volumes == 1 ? 'volume' : 'volumes'} · ${d.categoria.nome}'),
              const SizedBox(height: 4),
              Etiqueta(texto: '${nomeRisco(risco)} · ${textoValidade(d.diasParaVencer)}', cor: corRisco(risco)),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: repo.usuario.operaGeladeiras
            ? IconButton(
                tooltip: 'Marcar como retirado',
                icon: const Icon(Icons.task_alt, color: Cores.verde),
                onPressed: () => _marcarRetirada(d),
              )
            : null,
      ),
    );
  }
}
