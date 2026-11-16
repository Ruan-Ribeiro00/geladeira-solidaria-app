import 'package:flutter/material.dart';

import '../models/modelos.dart';
import '../tema.dart';

/// Situação de uma geladeira (RN1 da API Java), já com texto e cor para a tela.
class Situacao {
  final String texto;
  final String detalhe;
  final Color cor;
  final IconData icone;

  const Situacao(this.texto, this.detalhe, this.cor, this.icone);
}

/// Resposta do registro de doação (RN4). Quando a doação não cabe,
/// [sugestao] traz a geladeira ativa com mais espaço livre.
class ResultadoDoacao {
  final bool sucesso;
  final String mensagem;
  final Geladeira? sugestao;

  const ResultadoDoacao(this.sucesso, this.mensagem, {this.sugestao});
}

/// Guarda os dados do app em memória (dados mockados, permitidos pela disciplina)
/// e aplica as mesmas regras de negócio da API Java.
///
/// É um objeto único (singleton): todas as telas leem e alteram a mesma lista,
/// e cada tela chama `setState` para se redesenhar depois de uma alteração.
class Repositorio {
  Repositorio._() {
    reiniciar();
  }

  static final Repositorio instancia = Repositorio._();

  // ---------------------------------------------------------------- sessão
  Usuario usuario = const Usuario(nome: 'Visitante', email: '', papel: Papel.visitante);
  bool conectadoNaApi = false;
  String urlApi = 'http://10.0.2.2:8080'; // 10.0.2.2 = "localhost" do PC visto pelo emulador Android

  // ---------------------------------------------------------------- dados
  late List<Categoria> categorias;
  late List<Geladeira> geladeiras;
  late List<Doacao> doacoes;
  late List<Alerta> alertas;
  final Set<int> favoritas = {};
  int doacoesNaSessao = 0;
  int _proximoId = 1000;

  void sair() {
    usuario = const Usuario(nome: 'Visitante', email: '', papel: Papel.visitante);
    conectadoNaApi = false;
  }

  // ---------------------------------------------------------------- consultas

  Geladeira geladeira(int id) => geladeiras.firstWhere((g) => g.id == id);

  List<Doacao> doacoesDisponiveis(int geladeiraId) {
    final lista = doacoes.where((d) => d.geladeiraId == geladeiraId && !d.retirada).toList();
    lista.sort((a, b) => a.dtValidade.compareTo(b.dtValidade)); // vence primeiro, aparece primeiro
    return lista;
  }

  double ocupacaoKg(Geladeira g) =>
      doacoesDisponiveis(g.id).fold(0.0, (soma, d) => soma + d.quantidadeKg);

  double livreKg(Geladeira g) {
    final livre = g.capacidadeKg - ocupacaoKg(g);
    return livre < 0 ? 0 : livre;
  }

  double ocupacaoPct(Geladeira g) {
    final pct = ocupacaoKg(g) / g.capacidadeKg;
    return pct > 1 ? 1 : pct;
  }

  bool sensorOffline(Geladeira g) =>
      DateTime.now().difference(g.ultimaLeitura).inMinutes > Regras.sensorOfflineMin;

  /// RN1 — a ordem importa: temperatura vem antes de lotação porque é risco à saúde.
  Situacao situacao(Geladeira g) {
    final pct = ocupacaoPct(g);
    if (g.status == StatusGeladeira.manutencao) {
      return const Situacao('Em manutenção', 'Não está recebendo doações', Cores.neutro, Icons.build);
    }
    if (sensorOffline(g)) {
      return Situacao('Sensor offline', 'Sem leitura ${tempoAtras(g.ultimaLeitura)}', Cores.atencao,
          Icons.sensors_off);
    }
    if (g.temperaturaC > Regras.tempMaxGeral) {
      return Situacao('Temperatura alta', '${dec(g.temperaturaC)} °C (máx. 8 °C)',
          Cores.critico, Icons.thermostat);
    }
    if (pct >= Regras.lotada) {
      return Situacao('Lotada', '${(pct * 100).round()}% ocupada', Cores.atencao, Icons.inventory_2);
    }
    if (pct <= Regras.estoqueBaixo) {
      return Situacao('Precisa de doações', 'Só ${(pct * 100).round()}% ocupada', Cores.laranja,
          Icons.volunteer_activism);
    }
    return Situacao('Normal', '${(pct * 100).round()}% ocupada', Cores.ok, Icons.check_circle);
  }

  /// RN5 — risco de cada alimento.
  NivelRisco risco(Doacao d) {
    final dias = d.diasParaVencer;
    if (dias < 0) return NivelRisco.vencido;
    final g = geladeira(d.geladeiraId);
    final tempMax = d.categoria.tempMaxC;
    if (d.categoria.refrigerado && tempMax != null && g.temperaturaC > tempMax) {
      return NivelRisco.critico;
    }
    if (dias <= 1) return NivelRisco.critico;
    if (dias <= 3) return NivelRisco.atencao;
    return NivelRisco.ok;
  }

  int get alertasAbertos => alertas.where((a) => !a.resolvido).length;

  /// Geladeira ativa, com sensor funcionando, que tem mais espaço livre.
  Geladeira? geladeiraComMaisEspaco({int? exceto}) {
    final candidatas = geladeiras
        .where((g) =>
            g.id != exceto &&
            g.status == StatusGeladeira.ativa &&
            g.temperaturaC <= Regras.tempMaxGeral)
        .toList();
    if (candidatas.isEmpty) return null;
    candidatas.sort((a, b) => livreKg(b).compareTo(livreKg(a)));
    return candidatas.first;
  }

  // ---------------------------------------------------------------- alterações

  void alternarFavorita(int geladeiraId) {
    if (!favoritas.remove(geladeiraId)) favoritas.add(geladeiraId);
  }

  /// RN4 — mesmas validações do `POST /api/doacoes` da API Java.
  ResultadoDoacao registrarDoacao({
    required Geladeira geladeira,
    required Categoria categoria,
    required String descricao,
    required double quantidadeKg,
    required int volumes,
    required DateTime dtValidade,
  }) {
    final hoje = DateUtils.dateOnly(DateTime.now());
    if (quantidadeKg <= 0) {
      return const ResultadoDoacao(false, 'A quantidade precisa ser maior que zero.');
    }
    if (DateUtils.dateOnly(dtValidade).isBefore(hoje)) {
      return const ResultadoDoacao(false, 'Esse alimento já está vencido e não pode ser doado.');
    }
    if (geladeira.status != StatusGeladeira.ativa) {
      return ResultadoDoacao(false, '${geladeira.nome} está em manutenção.',
          sugestao: geladeiraComMaisEspaco(exceto: geladeira.id));
    }
    final tempMax = categoria.tempMaxC;
    if (categoria.refrigerado && tempMax != null && geladeira.temperaturaC > tempMax) {
      return ResultadoDoacao(
        false,
        '${categoria.nome} precisa de até ${tempMax.toStringAsFixed(0)} °C e esta geladeira '
        'está a ${dec(geladeira.temperaturaC)} °C.',
        sugestao: geladeiraComMaisEspaco(exceto: geladeira.id),
      );
    }
    final livre = livreKg(geladeira);
    if (quantidadeKg > livre) {
      return ResultadoDoacao(
        false,
        'Não cabe: ${geladeira.nome} tem só ${dec(livre)} kg livres.',
        sugestao: geladeiraComMaisEspaco(exceto: geladeira.id),
      );
    }

    doacoes.add(Doacao(
      id: _proximoId++,
      geladeiraId: geladeira.id,
      descricao: descricao,
      categoria: categoria,
      quantidadeKg: quantidadeKg,
      volumes: volumes,
      dtValidade: dtValidade,
      dtDoacao: DateTime.now(),
      doador: usuario.nome,
    ));
    doacoesNaSessao++;

    final pct = ocupacaoPct(geladeira);
    if (pct >= Regras.lotada &&
        !alertas.any((a) =>
            a.geladeiraId == geladeira.id && a.tipo == TipoAlerta.capacidade && !a.resolvido)) {
      alertas.insert(
        0,
        Alerta(
          id: _proximoId++,
          geladeiraId: geladeira.id,
          tipo: TipoAlerta.capacidade,
          nivel: NivelAlerta.alto,
          mensagem: '${geladeira.nome} passou de 90% da capacidade.',
          dtAlerta: DateTime.now(),
        ),
      );
    }
    return ResultadoDoacao(true, 'Doação registrada! ${geladeira.nome} está ${(pct * 100).round()}% ocupada.');
  }

  void marcarRetirada(Doacao d, bool retirada) => d.retirada = retirada;

  void resolverAlerta(Alerta a, bool resolvido) => a.resolvido = resolvido;

  // ---------------------------------------------------------------- dados iniciais

  /// Recria os dados de exemplo. As datas são relativas a hoje, então o
  /// cenário é o mesmo em qualquer dia (igual ao V2 do Flyway na API Java).
  void reiniciar() {
    final agora = DateTime.now();
    DateTime dia(int d) => DateUtils.dateOnly(agora).add(Duration(days: d));
    DateTime minAtras(int m) => agora.subtract(Duration(minutes: m));

    categorias = const [
      Categoria(id: 1, nome: 'Frutas', refrigerado: false, icone: Icons.apple),
      Categoria(id: 2, nome: 'Verduras e legumes', refrigerado: true, tempMaxC: 10, icone: Icons.eco),
      Categoria(id: 3, nome: 'Laticínios', refrigerado: true, tempMaxC: 8, icone: Icons.local_drink),
      Categoria(id: 4, nome: 'Refeições prontas', refrigerado: true, tempMaxC: 5, icone: Icons.lunch_dining),
      Categoria(id: 5, nome: 'Pães e bolos', refrigerado: false, icone: Icons.bakery_dining),
      Categoria(id: 6, nome: 'Frios', refrigerado: true, tempMaxC: 8, icone: Icons.kebab_dining),
      Categoria(id: 7, nome: 'Ovos', refrigerado: true, tempMaxC: 10, icone: Icons.egg),
      Categoria(id: 8, nome: 'Grãos e cereais', refrigerado: false, icone: Icons.grain),
      Categoria(id: 9, nome: 'Bebidas', refrigerado: false, icone: Icons.local_cafe),
      Categoria(id: 10, nome: 'Enlatados', refrigerado: false, icone: Icons.takeout_dining),
    ];
    Categoria cat(int id) => categorias.firstWhere((c) => c.id == id);

    geladeiras = [
      Geladeira(id: 1, nome: 'Geladeira Solidária Capão Redondo', endereco: 'Estrada de Itapecerica, 5859',
          bairro: 'Capão Redondo', capacidadeKg: 60, responsavel: 'Associação Comunitária Capão',
          horario: '24 horas', status: StatusGeladeira.ativa, temperaturaC: 4.6, umidadePct: 58,
          portaAberta: false, ultimaLeitura: minAtras(3)),
      Geladeira(id: 2, nome: 'Geladeira Solidária Heliópolis', endereco: 'Rua da Mina, 38',
          bairro: 'Heliópolis', capacidadeKg: 80, responsavel: 'UNAS Heliópolis',
          horario: '7h às 22h', status: StatusGeladeira.ativa, temperaturaC: 9.8, umidadePct: 71,
          portaAberta: false, ultimaLeitura: minAtras(2)),
      Geladeira(id: 3, nome: 'Geladeira Solidária Jardim Ângela', endereco: 'Estrada do M\'Boi Mirim, 3920',
          bairro: 'Jardim Ângela', capacidadeKg: 70, responsavel: 'Paróquia Santos Mártires',
          horario: '8h às 20h', status: StatusGeladeira.ativa, temperaturaC: 5.1, umidadePct: 62,
          portaAberta: false, ultimaLeitura: minAtras(5)),
      Geladeira(id: 4, nome: 'Geladeira Solidária Paraisópolis', endereco: 'Rua Ernest Renan, 1366',
          bairro: 'Paraisópolis', capacidadeKg: 100, responsavel: 'União dos Moradores de Paraisópolis',
          horario: '24 horas', status: StatusGeladeira.ativa, temperaturaC: 3.9, umidadePct: 55,
          portaAberta: true, ultimaLeitura: minAtras(1)),
      Geladeira(id: 5, nome: 'Geladeira Solidária Brasilândia', endereco: 'Av. Deputado Cantídio Sampaio, 1730',
          bairro: 'Brasilândia', capacidadeKg: 60, responsavel: 'Coletivo Brasilândia Solidária',
          horario: '8h às 18h', status: StatusGeladeira.manutencao, temperaturaC: 12.4, umidadePct: 80,
          portaAberta: false, ultimaLeitura: minAtras(20)),
      Geladeira(id: 6, nome: 'Geladeira Solidária Cidade Tiradentes', endereco: 'Rua Inácio Monteiro, 6900',
          bairro: 'Cidade Tiradentes', capacidadeKg: 80, responsavel: 'Instituto Tiradentes',
          horario: '7h às 21h', status: StatusGeladeira.ativa, temperaturaC: 4.2, umidadePct: 60,
          portaAberta: false, ultimaLeitura: minAtras(4)),
      Geladeira(id: 7, nome: 'Geladeira Solidária Itaquera', endereco: 'Av. Itaquera, 8266',
          bairro: 'Itaquera', capacidadeKg: 100, responsavel: 'Rede Itaquera Sem Fome',
          horario: '24 horas', status: StatusGeladeira.ativa, temperaturaC: 4.0, umidadePct: 57,
          portaAberta: false, ultimaLeitura: minAtras(2)),
      Geladeira(id: 8, nome: 'Geladeira Solidária Grajaú', endereco: 'Av. Dona Belmira Marin, 2460',
          bairro: 'Grajaú', capacidadeKg: 70, responsavel: 'Casa de Cultura Grajaú',
          horario: '8h às 22h', status: StatusGeladeira.ativa, temperaturaC: 5.5, umidadePct: 64,
          portaAberta: false, ultimaLeitura: minAtras(6)),
      Geladeira(id: 9, nome: 'Geladeira Solidária Centro (Sé)', endereco: 'Rua Tabatinguera, 140',
          bairro: 'Sé', capacidadeKg: 90, responsavel: 'Movimento Centro Solidário',
          horario: '24 horas', status: StatusGeladeira.ativa, temperaturaC: 4.8, umidadePct: 59,
          portaAberta: false, ultimaLeitura: minAtras(1)),
      Geladeira(id: 10, nome: 'Geladeira Solidária Vila Prudente', endereco: 'Av. Professor Luiz Ignácio Anhaia Mello, 3300',
          bairro: 'Vila Prudente', capacidadeKg: 60, responsavel: 'Associação Vila Prudente',
          horario: '8h às 20h', status: StatusGeladeira.ativa, temperaturaC: 5.0, umidadePct: 61,
          portaAberta: false, ultimaLeitura: minAtras(95)),
    ];

    var id = 1;
    Doacao d(int geladeira, String descricao, int categoria, double kg, int validade, String doador,
            {int volumes = 1, int doadoHa = 1}) =>
        Doacao(
          id: id++,
          geladeiraId: geladeira,
          descricao: descricao,
          categoria: cat(categoria),
          quantidadeKg: kg,
          volumes: volumes,
          dtValidade: dia(validade),
          dtDoacao: agora.subtract(Duration(days: doadoHa, hours: id % 7)),
          doador: doador,
        );

    doacoes = [
      // Capão Redondo: quase lotada (59 de 60 kg)
      d(1, 'Arroz 5 kg', 8, 25, 180, 'Mercado Bom Preço', volumes: 5),
      d(1, 'Feijão carioca', 8, 15, 150, 'Mercado Bom Preço', volumes: 15),
      d(1, 'Bananas', 1, 8, 4, 'Feira da Rua Augusta'),
      d(1, 'Pão francês', 5, 6, 1, 'Padaria Estrela', doadoHa: 0),
      d(1, 'Iogurte natural', 3, 5, 6, 'Laticínios Serra Azul', volumes: 10),
      // Heliópolis: refrigeração com problema (9,8 °C)
      d(2, 'Leite integral', 3, 12, 5, 'Laticínios Serra Azul', volumes: 12),
      d(2, 'Marmitas de arroz e frango', 4, 6, 1, 'Restaurante Sabor da Casa', volumes: 12, doadoHa: 0),
      d(2, 'Maçãs', 1, 7, 8, 'Feira da Rua Augusta'),
      d(2, 'Biscoitos', 5, 4, 60, 'Ana Souza'),
      // Jardim Ângela
      d(3, 'Queijo minas frescal', 3, 3, 1, 'Laticínios Serra Azul', volumes: 6),
      d(3, 'Alface e couve', 2, 4, 2, 'Horta Comunitária M\'Boi'),
      d(3, 'Macarrão', 8, 10, 200, 'Carlos Lima', volumes: 20),
      d(3, 'Laranjas', 1, 9, 9, 'Feira da Rua Augusta'),
      // Paraisópolis
      d(4, 'Marmitas de feijoada', 4, 8, 2, 'Restaurante Sabor da Casa', volumes: 16),
      d(4, 'Ovos', 7, 6, 18, 'Granja Boa Vista', volumes: 5),
      d(4, 'Tomates e cenouras', 2, 10, 5, 'Horta Comunitária M\'Boi'),
      d(4, 'Leite em pó', 3, 6, 240, 'Mercado Bom Preço', volumes: 15),
      d(4, 'Pão de forma', 5, 5, 4, 'Padaria Estrela', volumes: 10),
      // Cidade Tiradentes: estoque baixo
      d(6, 'Bananas', 1, 5, 3, 'Ana Souza'),
      d(6, 'Suco de caixinha', 9, 6, 90, 'Carlos Lima', volumes: 6),
      // Itaquera: bastante espaço
      d(7, 'Presunto e muçarela fatiados', 6, 4, 4, 'Mercado Bom Preço', volumes: 8),
      d(7, 'Sardinha em lata', 10, 6, 400, 'Igreja Batista Itaquera', volumes: 24),
      d(7, 'Batatas', 2, 12, 12, 'Feira da Rua Augusta'),
      // Grajaú
      d(8, 'Iogurte de morango', 3, 4, 3, 'Laticínios Serra Azul', volumes: 8),
      d(8, 'Mamão e melão', 1, 14, 5, 'Feira da Rua Augusta'),
      d(8, 'Marmitas vegetarianas', 4, 5, 1, 'Restaurante Sabor da Casa', volumes: 10, doadoHa: 0),
      d(8, 'Aveia e granola', 8, 6, 120, 'Ana Souza', volumes: 6),
      // Centro (Sé)
      d(9, 'Sanduíches naturais', 4, 6, 1, 'Café do Largo', volumes: 20, doadoHa: 0),
      d(9, 'Bolo de cenoura', 5, 4, 3, 'Padaria Estrela'),
      d(9, 'Leite integral', 3, 12, 7, 'Laticínios Serra Azul', volumes: 12),
      d(9, 'Feijão preto', 8, 20, 160, 'Mercado Bom Preço', volumes: 20),
      d(9, 'Água mineral', 9, 12, 300, 'Carlos Lima', volumes: 24),
      // Vila Prudente: sensor sem leitura
      d(10, 'Ovos', 7, 4, 15, 'Granja Boa Vista', volumes: 3),
      d(10, 'Milho e ervilha em lata', 10, 6, 365, 'Igreja Batista Itaquera', volumes: 12),
      d(10, 'Couve-flor e brócolis', 2, 5, 3, 'Horta Comunitária M\'Boi'),
    ];

    alertas = [
      Alerta(id: 1, geladeiraId: 2, tipo: TipoAlerta.temperatura, nivel: NivelAlerta.critico,
          mensagem: 'Geladeira Solidária Heliópolis está a 9,8 °C (máx. 8 °C). Leite e marmitas em risco.',
          dtAlerta: minAtras(12)),
      Alerta(id: 2, geladeiraId: 1, tipo: TipoAlerta.capacidade, nivel: NivelAlerta.alto,
          mensagem: 'Geladeira Solidária Capão Redondo passou de 90% da capacidade.',
          dtAlerta: minAtras(48)),
      Alerta(id: 3, geladeiraId: 3, tipo: TipoAlerta.validade, nivel: NivelAlerta.critico,
          mensagem: 'Queijo minas frescal (Jardim Ângela) vence amanhã. Priorize a distribuição.',
          dtAlerta: minAtras(75)),
      Alerta(id: 4, geladeiraId: 6, tipo: TipoAlerta.estoqueBaixo, nivel: NivelAlerta.info,
          mensagem: 'Geladeira Solidária Cidade Tiradentes está com só 14% de ocupação.',
          dtAlerta: minAtras(130)),
      Alerta(id: 5, geladeiraId: 9, tipo: TipoAlerta.validade, nivel: NivelAlerta.alto,
          mensagem: 'Sanduíches naturais (Centro) vencem amanhã.',
          dtAlerta: minAtras(200)),
      Alerta(id: 6, geladeiraId: 4, tipo: TipoAlerta.temperatura, nivel: NivelAlerta.alto,
          mensagem: 'Porta da geladeira de Paraisópolis ficou aberta por 4 minutos.',
          dtAlerta: minAtras(26 * 60), resolvido: true),
    ];

    favoritas.clear();
    doacoesNaSessao = 0;
    _proximoId = 1000;
  }
}

// ---------------------------------------------------------------- formatação de datas

/// Número com vírgula, no formato brasileiro (ex.: 9,8).
String dec(double v, [int casas = 1]) => v.toStringAsFixed(casas).replaceAll('.', ',');

String doisDigitos(int n) => n.toString().padLeft(2, '0');

String formatarData(DateTime d) => '${doisDigitos(d.day)}/${doisDigitos(d.month)}/${d.year}';

String tempoAtras(DateTime d) {
  final dif = DateTime.now().difference(d);
  if (dif.inMinutes < 1) return 'agora';
  if (dif.inMinutes < 60) return 'há ${dif.inMinutes} min';
  if (dif.inHours < 24) return 'há ${dif.inHours} h';
  return 'há ${dif.inDays} ${dif.inDays == 1 ? 'dia' : 'dias'}';
}

String textoValidade(int dias) {
  if (dias < 0) return 'Venceu há ${-dias} ${dias == -1 ? 'dia' : 'dias'}';
  if (dias == 0) return 'Vence hoje';
  if (dias == 1) return 'Vence amanhã';
  return 'Vence em $dias dias';
}
