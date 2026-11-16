import 'package:flutter/material.dart';

import '../tema.dart';

/// Os modelos seguem as tabelas da API Java (GELADEIRA, CATEGORIA, DOACAO, ALERTA, USUARIO).

enum StatusGeladeira { ativa, manutencao }

enum Papel { visitante, doador, voluntario, admin }

enum NivelRisco { ok, atencao, critico, vencido }

enum TipoAlerta { temperatura, validade, capacidade, estoqueBaixo }

enum NivelAlerta { info, alto, critico }

/// Limites das regras de negócio (iguais ao `app.regras` da API Java).
class Regras {
  static const tempMaxGeral = 8.0; // °C
  static const lotada = 0.90; // 90% da capacidade
  static const estoqueBaixo = 0.20; // 20% da capacidade
  static const sensorOfflineMin = 60; // minutos sem leitura
}

class Categoria {
  final int id;
  final String nome;
  final bool refrigerado;
  final double? tempMaxC;
  final IconData icone;

  const Categoria({
    required this.id,
    required this.nome,
    required this.refrigerado,
    this.tempMaxC,
    required this.icone,
  });
}

class Geladeira {
  final int id;
  final String nome;
  final String endereco;
  final String bairro;
  final double capacidadeKg;
  final String responsavel;
  final String horario;
  StatusGeladeira status;

  // Última leitura do sensor IoT (ESP32 → MQTT → API)
  double temperaturaC;
  double umidadePct;
  bool portaAberta;
  DateTime ultimaLeitura;

  Geladeira({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.bairro,
    required this.capacidadeKg,
    required this.responsavel,
    required this.horario,
    required this.status,
    required this.temperaturaC,
    required this.umidadePct,
    required this.portaAberta,
    required this.ultimaLeitura,
  });
}

class Doacao {
  final int id;
  final int geladeiraId;
  final String descricao;
  final Categoria categoria;
  final double quantidadeKg;
  final int volumes;
  final DateTime dtValidade;
  final DateTime dtDoacao;
  final String doador;
  bool retirada;

  Doacao({
    required this.id,
    required this.geladeiraId,
    required this.descricao,
    required this.categoria,
    required this.quantidadeKg,
    this.volumes = 1,
    required this.dtValidade,
    required this.dtDoacao,
    required this.doador,
    this.retirada = false,
  });

  /// Dias até vencer (0 = vence hoje, negativo = vencido).
  int get diasParaVencer {
    final hoje = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(dtValidade).difference(hoje).inDays;
  }
}

class Alerta {
  final int id;
  final int geladeiraId;
  final TipoAlerta tipo;
  final NivelAlerta nivel;
  final String mensagem;
  final DateTime dtAlerta;
  bool resolvido;

  Alerta({
    required this.id,
    required this.geladeiraId,
    required this.tipo,
    required this.nivel,
    required this.mensagem,
    required this.dtAlerta,
    this.resolvido = false,
  });
}

class Usuario {
  final String nome;
  final String email;
  final Papel papel;
  final String? token; // JWT devolvido pela API Java (null no modo offline)

  const Usuario({required this.nome, required this.email, required this.papel, this.token});

  bool get podeDoar => papel != Papel.visitante;
  bool get operaGeladeiras => papel == Papel.voluntario || papel == Papel.admin;

  static Papel papelDaApi(String? valor) {
    switch (valor) {
      case 'ADMIN':
        return Papel.admin;
      case 'VOLUNTARIO':
        return Papel.voluntario;
      case 'DOADOR':
        return Papel.doador;
      default:
        return Papel.visitante;
    }
  }
}

// ----------------------------------------------------------------- textos e cores

String nomePapel(Papel p) {
  switch (p) {
    case Papel.visitante:
      return 'Visitante';
    case Papel.doador:
      return 'Doador';
    case Papel.voluntario:
      return 'Voluntário';
    case Papel.admin:
      return 'Administrador';
  }
}

String nomeRisco(NivelRisco r) {
  switch (r) {
    case NivelRisco.ok:
      return 'OK';
    case NivelRisco.atencao:
      return 'Atenção';
    case NivelRisco.critico:
      return 'Crítico';
    case NivelRisco.vencido:
      return 'Vencido';
  }
}

Color corRisco(NivelRisco r) {
  switch (r) {
    case NivelRisco.ok:
      return Cores.ok;
    case NivelRisco.atencao:
      return Cores.atencao;
    case NivelRisco.critico:
    case NivelRisco.vencido:
      return Cores.critico;
  }
}

String nomeTipoAlerta(TipoAlerta t) {
  switch (t) {
    case TipoAlerta.temperatura:
      return 'Temperatura';
    case TipoAlerta.validade:
      return 'Validade';
    case TipoAlerta.capacidade:
      return 'Capacidade';
    case TipoAlerta.estoqueBaixo:
      return 'Estoque baixo';
  }
}

IconData iconeTipoAlerta(TipoAlerta t) {
  switch (t) {
    case TipoAlerta.temperatura:
      return Icons.thermostat;
    case TipoAlerta.validade:
      return Icons.event_busy;
    case TipoAlerta.capacidade:
      return Icons.inventory_2;
    case TipoAlerta.estoqueBaixo:
      return Icons.production_quantity_limits;
  }
}

String nomeNivelAlerta(NivelAlerta n) {
  switch (n) {
    case NivelAlerta.info:
      return 'Info';
    case NivelAlerta.alto:
      return 'Alto';
    case NivelAlerta.critico:
      return 'Crítico';
  }
}

Color corNivelAlerta(NivelAlerta n) {
  switch (n) {
    case NivelAlerta.info:
      return Cores.verde;
    case NivelAlerta.alto:
      return Cores.atencao;
    case NivelAlerta.critico:
      return Cores.critico;
  }
}
