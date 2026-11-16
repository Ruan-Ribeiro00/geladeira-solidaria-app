import 'package:flutter/material.dart';

import '../data/repositorio.dart';
import '../models/modelos.dart';
import '../tema.dart';

/// Etiqueta colorida (situação da geladeira, risco do alimento, nível do alerta).
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor;
  final IconData? icone;

  const Etiqueta({super.key, required this.texto, required this.cor, this.icone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(cor.withAlpha(30), Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withAlpha(110)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 14, color: cor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Barra de ocupação da geladeira (verde → amarela → vermelha).
class BarraOcupacao extends StatelessWidget {
  final double pct; // 0 a 1
  final double altura;

  const BarraOcupacao({super.key, required this.pct, this.altura = 8});

  @override
  Widget build(BuildContext context) {
    final cor = pct >= Regras.lotada
        ? Cores.critico
        : pct >= 0.7
            ? Cores.atencao
            : Cores.ok;
    return ClipRRect(
      borderRadius: BorderRadius.circular(altura),
      child: LinearProgressIndicator(
        value: pct,
        minHeight: altura,
        color: cor,
        backgroundColor: const Color(0xFFE6ECE8),
      ),
    );
  }
}

/// Menu lateral, igual em todas as telas principais.
class MenuLateral extends StatelessWidget {
  final String rotaAtual;

  const MenuLateral({super.key, required this.rotaAtual});

  @override
  Widget build(BuildContext context) {
    final repo = Repositorio.instancia;
    final usuario = repo.usuario;

    Widget item(IconData icone, String titulo, String rota, {Widget? trailing}) {
      final selecionado = rota == rotaAtual;
      return ListTile(
        leading: Icon(icone, color: selecionado ? Cores.verde : Cores.textoSuave),
        title: Text(titulo,
            style: TextStyle(fontWeight: selecionado ? FontWeight.bold : FontWeight.normal)),
        trailing: trailing,
        selected: selecionado,
        selectedTileColor: Cores.verdeClaro,
        onTap: () {
          Navigator.pop(context); // fecha o menu
          if (!selecionado) Navigator.pushReplacementNamed(context, rota);
        },
      );
    }

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Cores.verde),
            currentAccountPicture: const LogoApp(tamanho: 64, claro: true),
            accountName: Text(usuario.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(usuario.email.isEmpty
                ? nomePapel(usuario.papel)
                : '${usuario.email} · ${nomePapel(usuario.papel)}'),
          ),
          item(Icons.kitchen_outlined, 'Geladeiras', '/geladeiras'),
          if (usuario.operaGeladeiras)
            item(Icons.notifications_outlined, 'Alertas', '/alertas',
                trailing: repo.alertasAbertos > 0
                    ? Etiqueta(texto: '${repo.alertasAbertos}', cor: Cores.critico)
                    : null),
          item(Icons.person_outline, 'Perfil e impacto', '/perfil'),
          const Spacer(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(usuario.papel == Papel.visitante ? 'Entrar com login' : 'Sair'),
            onTap: () {
              repo.sair();
              Navigator.pushNamedAndRemoveUntil(context, '/', (rota) => false);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Mensagem para lista vazia.
class ListaVazia extends StatelessWidget {
  final IconData icone;
  final String texto;

  const ListaVazia({super.key, required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(icone, size: 56, color: Cores.neutro),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Cores.textoSuave)),
        ],
      ),
    );
  }
}
