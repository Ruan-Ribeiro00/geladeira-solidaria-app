import 'package:flutter/material.dart';

import '../data/repositorio.dart';
import '../models/modelos.dart';
import '../tema.dart';

/// Tela 4 — Registrar doação. Formulário com `GlobalKey<FormState>`, validações,
/// contador de volumes (setState) e SnackBar com o resultado das regras (RN4).
class NovaDoacaoScreen extends StatefulWidget {
  const NovaDoacaoScreen({super.key});

  @override
  State<NovaDoacaoScreen> createState() => _NovaDoacaoScreenState();
}

class _NovaDoacaoScreenState extends State<NovaDoacaoScreen> {
  final repo = Repositorio.instancia;
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _quantidadeController = TextEditingController();
  final _validadeController = TextEditingController();

  Geladeira? _geladeira;
  Categoria? _categoria;
  DateTime? _validade;
  int _volumes = 1;
  bool _declarou = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A geladeira vem como parâmetro da rota (id)
    if (_geladeira == null) {
      final id = ModalRoute.of(context)?.settings.arguments as int?;
      _geladeira = id == null ? null : repo.geladeira(id);
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _quantidadeController.dispose();
    _validadeController.dispose();
    super.dispose();
  }

  double? _lerKg(String? texto) => double.tryParse((texto ?? '').trim().replaceAll(',', '.'));

  Future<void> _escolherValidade() async {
    final hoje = DateUtils.dateOnly(DateTime.now());
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _validade ?? hoje.add(const Duration(days: 3)),
      firstDate: hoje.subtract(const Duration(days: 30)), // permite escolher vencido para a validação avisar
      lastDate: hoje.add(const Duration(days: 730)),
      helpText: 'Validade do alimento',
    );
    if (escolhida != null) {
      setState(() {
        _validade = escolhida;
        _validadeController.text = formatarData(escolhida);
      });
    }
  }

  void _enviar() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (!_formKey.currentState!.validate()) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Confira os campos destacados.'),
        backgroundColor: Cores.critico,
      ));
      return;
    }
    if (!_declarou) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Confirme que o alimento está embalado e em bom estado.'),
        backgroundColor: Cores.atencao,
      ));
      return;
    }

    final resultado = repo.registrarDoacao(
      geladeira: _geladeira!,
      categoria: _categoria!,
      descricao: _descricaoController.text.trim(),
      quantidadeKg: _lerKg(_quantidadeController.text)!,
      volumes: _volumes,
      dtValidade: _validade!,
    );

    if (resultado.sucesso) {
      messenger.showSnackBar(SnackBar(content: Text(resultado.mensagem), backgroundColor: Cores.ok));
      Navigator.pop(context, true);
      return;
    }

    final sugestao = resultado.sugestao;
    messenger.showSnackBar(SnackBar(
      content: Text(resultado.mensagem),
      backgroundColor: Cores.critico,
      duration: const Duration(seconds: 6),
      action: sugestao == null
          ? null
          : SnackBarAction(
              label: 'Usar ${sugestao.bairro}',
              textColor: Colors.white,
              onPressed: () => setState(() => _geladeira = sugestao),
            ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ativas = repo.geladeiras.where((g) => g.status == StatusGeladeira.ativa).toList();
    final g = _geladeira;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar doação')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<Geladeira>(
              key: const Key('campoGeladeira'),
              // ignore: deprecated_member_use
              value: g,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Geladeira',
                prefixIcon: Icon(Icons.kitchen_outlined),
              ),
              items: ativas
                  .map((x) => DropdownMenuItem(value: x, child: Text(x.bairro, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (x) => setState(() => _geladeira = x),
              validator: (x) => x == null ? 'Escolha a geladeira' : null,
            ),
            if (g != null) _resumoGeladeira(g),
            const SizedBox(height: 16),
            DropdownButtonFormField<Categoria>(
              key: const Key('campoCategoria'),
              // ignore: deprecated_member_use
              value: _categoria,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: repo.categorias
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(c.icone, size: 20, color: Cores.verde),
                            const SizedBox(width: 8),
                            Expanded(child: Text(c.nome)),
                            if (c.refrigerado) const Icon(Icons.ac_unit, size: 16, color: Cores.textoSuave),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (c) => setState(() => _categoria = c),
              validator: (c) => c == null ? 'Escolha a categoria' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('campoDescricao'),
              controller: _descricaoController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'O que você está doando?',
                hintText: 'Ex.: Iogurte natural, marmitas de arroz e feijão',
                prefixIcon: Icon(Icons.edit_note),
              ),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return 'Descreva o alimento';
                if (v!.trim().length < 3) return 'Descrição muito curta';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('campoQuantidade'),
              controller: _quantidadeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantidade (kg)',
                hintText: 'Ex.: 2,5',
                prefixIcon: Icon(Icons.scale_outlined),
                suffixText: 'kg',
              ),
              validator: (v) {
                final kg = _lerKg(v);
                if (kg == null) return 'Informe a quantidade em kg';
                if (kg <= 0) return 'A quantidade precisa ser maior que zero';
                if (kg > 100) return 'Para mais de 100 kg, fale com um voluntário';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('campoValidade'),
              controller: _validadeController,
              readOnly: true,
              onTap: _escolherValidade,
              decoration: const InputDecoration(
                labelText: 'Validade',
                prefixIcon: Icon(Icons.event_outlined),
                suffixIcon: Icon(Icons.calendar_month),
              ),
              validator: (_) {
                if (_validade == null) return 'Escolha a data de validade';
                if (_validade!.isBefore(DateUtils.dateOnly(DateTime.now()))) {
                  return 'Alimento vencido não pode ser doado';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // ------------------------------------------------ contador (setState)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB9C4BE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: Cores.textoSuave),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Volumes / embalagens')),
                  IconButton(
                    key: const Key('menosVolume'),
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Cores.verde,
                    onPressed: _volumes > 1 ? () => setState(() => _volumes--) : null,
                  ),
                  Text('$_volumes',
                      key: const Key('contadorVolumes'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    key: const Key('maisVolume'),
                    icon: const Icon(Icons.add_circle_outline),
                    color: Cores.verde,
                    onPressed: _volumes < 99 ? () => setState(() => _volumes++) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('checkDeclaracao'),
              value: _declarou,
              onChanged: (v) => setState(() => _declarou = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: Cores.verde,
              title: const Text('O alimento está embalado, identificado e em bom estado.'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              key: const Key('botaoRegistrar'),
              onPressed: _enviar,
              icon: const Icon(Icons.volunteer_activism),
              label: const Text('Registrar doação'),
            ),
            const SizedBox(height: 8),
            Text(
              'Doando como ${repo.usuario.nome}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Cores.textoSuave, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumoGeladeira(Geladeira g) {
    final livre = repo.livreKg(g);
    final quente = g.temperaturaC > Regras.tempMaxGeral;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: quente ? const Color(0xFFFDECEC) : Cores.verdeClaro,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(quente ? Icons.warning_amber : Icons.info_outline,
              color: quente ? Cores.critico : Cores.verde),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cabem ${dec(livre)} kg · ${dec(g.temperaturaC)} °C'
              '${quente ? ' (quente: evite refrigerados)' : ''}',
            ),
          ),
        ],
      ),
    );
  }
}
