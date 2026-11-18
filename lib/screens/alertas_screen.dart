import 'package:flutter/material.dart';

import '../data/repositorio.dart';
import '../models/modelos.dart';
import '../tema.dart';
import '../widgets/componentes.dart';

/// Tela 5 — Alertas para os voluntários (temperatura, validade, capacidade e estoque baixo).
/// Filtro por nível, opção de ver resolvidos e botão de resolver (setState + SnackBar).
class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  final repo = Repositorio.instancia;
  NivelAlerta? _nivel; // null = todos
  bool _mostrarResolvidos = false;

  List<Alerta> get _filtrados {
    final lista = repo.alertas
        .where((a) => (_mostrarResolvidos || !a.resolvido) && (_nivel == null || a.nivel == _nivel))
        .toList();
    // abertos primeiro, depois do mais grave para o menos grave, depois os mais recentes
    lista.sort((a, b) {
      if (a.resolvido != b.resolvido) return a.resolvido ? 1 : -1;
      final porNivel = b.nivel.index.compareTo(a.nivel.index);
      if (porNivel != 0) return porNivel;
      return b.dtAlerta.compareTo(a.dtAlerta);
    });
    return lista;
  }

  void _resolver(Alerta a) {
    setState(() => repo.resolverAlerta(a, true));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Alerta de ${nomeTipoAlerta(a.tipo).toLowerCase()} resolvido.'),
      backgroundColor: Cores.ok,
      action: SnackBarAction(
        label: 'Desfazer',
        textColor: Colors.white,
        onPressed: () => setState(() => repo.resolverAlerta(a, false)),
      ),
    ));
  }

  Widget _chipNivel(String texto, NivelAlerta? nivel) {
    final selecionado = _nivel == nivel;
    final abertos = repo.alertas.where((a) => !a.resolvido && (nivel == null || a.nivel == nivel)).length;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$texto ($abertos)'),
        selected: selecionado,
        showCheckmark: false,
        selectedColor: nivel == null ? Cores.verde : corNivelAlerta(nivel),
        labelStyle: TextStyle(color: selecionado ? Colors.white : Cores.texto),
        onSelected: (_) => setState(() => _nivel = nivel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtrados;
    return Scaffold(
      appBar: AppBar(title: const Text('Alertas')),
      drawer: const MenuLateral(rotaAtual: '/alertas'),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _chipNivel('Todos', null),
                _chipNivel('Crítico', NivelAlerta.critico),
                _chipNivel('Alto', NivelAlerta.alto),
                _chipNivel('Info', NivelAlerta.info),
              ],
            ),
          ),
          SwitchListTile(
            key: const Key('switchResolvidos'),
            title: const Text('Mostrar alertas resolvidos'),
            value: _mostrarResolvidos,
            activeTrackColor: Cores.verde,
            onChanged: (v) => setState(() => _mostrarResolvidos = v),
          ),
          Expanded(
            child: lista.isEmpty
                ? ListView(children: const [
                    ListaVazia(icone: Icons.notifications_off_outlined, texto: 'Nenhum alerta aberto. Tudo certo!'),
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

  Widget _cartao(Alerta a) {
    final cor = a.resolvido ? Cores.neutro : corNivelAlerta(a.nivel);
    final g = repo.geladeira(a.geladeiraId);
    return Card(
      key: Key('alerta-${a.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.pushNamed(context, '/detalhe', arguments: a.geladeiraId);
          setState(() {});
        },
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: cor, width: 5))),
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconeTipoAlerta(a.tipo), color: cor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(nomeTipoAlerta(a.tipo),
                        overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Etiqueta(texto: a.resolvido ? 'Resolvido' : nomeNivelAlerta(a.nivel), cor: cor),
                  const Spacer(),
                  Text(tempoAtras(a.dtAlerta), style: const TextStyle(fontSize: 12, color: Cores.textoSuave)),
                ],
              ),
              const SizedBox(height: 8),
              Text(a.mensagem,
                  style: TextStyle(
                    color: a.resolvido ? Cores.textoSuave : Cores.texto,
                    decoration: a.resolvido ? TextDecoration.lineThrough : null,
                  )),
              Row(
                children: [
                  Expanded(
                    child: Text(g.bairro, style: const TextStyle(fontSize: 12, color: Cores.textoSuave)),
                  ),
                  if (!a.resolvido)
                    TextButton.icon(
                      key: Key('resolver-${a.id}'),
                      onPressed: () => _resolver(a),
                      icon: const Icon(Icons.check),
                      label: const Text('Resolver'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
