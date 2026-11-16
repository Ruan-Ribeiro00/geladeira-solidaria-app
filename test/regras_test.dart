import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geladeira_solidaria/data/repositorio.dart';
import 'package:geladeira_solidaria/models/modelos.dart';

/// Testes das regras de negócio (as mesmas da API Java).
void main() {
  final repo = Repositorio.instancia;
  DateTime emDias(int d) => DateUtils.dateOnly(DateTime.now()).add(Duration(days: d));
  Categoria cat(String nome) => repo.categorias.firstWhere((c) => c.nome == nome);

  setUp(() {
    repo.reiniciar();
    repo.sair();
  });

  group('RN1 - situação da geladeira', () {
    test('cada geladeira de exemplo cai na situação esperada', () {
      expect(repo.situacao(repo.geladeira(1)).texto, 'Lotada');
      expect(repo.situacao(repo.geladeira(2)).texto, 'Temperatura alta');
      expect(repo.situacao(repo.geladeira(5)).texto, 'Em manutenção');
      expect(repo.situacao(repo.geladeira(6)).texto, 'Precisa de doações');
      expect(repo.situacao(repo.geladeira(9)).texto, 'Normal');
      expect(repo.situacao(repo.geladeira(10)).texto, 'Sensor offline');
    });
  });

  group('RN5 - risco do alimento', () {
    test('refrigerado em geladeira quente é crítico, mesmo longe de vencer', () {
      final leite = repo.doacoes.firstWhere((d) => d.geladeiraId == 2 && d.descricao == 'Leite integral');
      expect(leite.diasParaVencer, 5);
      expect(repo.risco(leite), NivelRisco.critico);
    });

    test('vence amanhã = crítico, em 2 ou 3 dias = atenção, depois = OK', () {
      final queijo = repo.doacoes.firstWhere((d) => d.descricao == 'Queijo minas frescal');
      final bananas = repo.doacoes.firstWhere((d) => d.geladeiraId == 6 && d.descricao == 'Bananas');
      final arroz = repo.doacoes.firstWhere((d) => d.descricao == 'Arroz 5 kg');
      expect(repo.risco(queijo), NivelRisco.critico);
      expect(repo.risco(bananas), NivelRisco.atencao);
      expect(repo.risco(arroz), NivelRisco.ok);
    });
  });

  group('RN4 - registro de doação', () {
    test('doação válida entra e aumenta a ocupação', () {
      final itaquera = repo.geladeira(7);
      final antes = repo.ocupacaoKg(itaquera);
      final r = repo.registrarDoacao(
        geladeira: itaquera,
        categoria: cat('Frutas'),
        descricao: 'Peras',
        quantidadeKg: 5,
        volumes: 2,
        dtValidade: emDias(6),
      );
      expect(r.sucesso, isTrue);
      expect(repo.ocupacaoKg(itaquera), antes + 5);
      expect(repo.doacoesNaSessao, 1);
    });

    test('alimento vencido é recusado', () {
      final r = repo.registrarDoacao(
        geladeira: repo.geladeira(7),
        categoria: cat('Frutas'),
        descricao: 'Uvas',
        quantidadeKg: 1,
        volumes: 1,
        dtValidade: emDias(-1),
      );
      expect(r.sucesso, isFalse);
      expect(r.mensagem, contains('vencido'));
    });

    test('doação que não cabe é recusada e sugere a geladeira com mais espaço', () {
      final r = repo.registrarDoacao(
        geladeira: repo.geladeira(1), // Capão Redondo: 1 kg livre
        categoria: cat('Grãos e cereais'),
        descricao: 'Arroz',
        quantidadeKg: 5,
        volumes: 1,
        dtValidade: emDias(90),
      );
      expect(r.sucesso, isFalse);
      expect(r.mensagem, contains('Não cabe'));
      expect(r.sugestao?.bairro, 'Itaquera');
    });

    test('refrigerado não entra em geladeira acima da temperatura da categoria', () {
      final r = repo.registrarDoacao(
        geladeira: repo.geladeira(2), // Heliópolis a 9,8 °C
        categoria: cat('Laticínios'),
        descricao: 'Iogurte',
        quantidadeKg: 2,
        volumes: 4,
        dtValidade: emDias(5),
      );
      expect(r.sucesso, isFalse);
      expect(r.mensagem, contains('°C'));
      expect(r.sugestao, isNotNull);
    });

    test('geladeira em manutenção não recebe doação', () {
      final r = repo.registrarDoacao(
        geladeira: repo.geladeira(5),
        categoria: cat('Frutas'),
        descricao: 'Maçãs',
        quantidadeKg: 1,
        volumes: 1,
        dtValidade: emDias(5),
      );
      expect(r.sucesso, isFalse);
      expect(r.mensagem, contains('manutenção'));
    });

    test('passar de 90% abre alerta de capacidade', () {
      final grajau = repo.geladeira(8); // 29 de 70 kg
      final alertasAntes = repo.alertasAbertos;
      final r = repo.registrarDoacao(
        geladeira: grajau,
        categoria: cat('Grãos e cereais'),
        descricao: 'Feijão',
        quantidadeKg: 36,
        volumes: 36,
        dtValidade: emDias(120),
      );
      expect(r.sucesso, isTrue);
      expect(repo.alertasAbertos, alertasAntes + 1);
      expect(repo.alertas.first.tipo, TipoAlerta.capacidade);
    });
  });
}
