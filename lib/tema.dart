import 'package:flutter/material.dart';

/// Identidade visual do app: verde (alimento, cuidado) + laranja (solidariedade).
class Cores {
  static const verde = Color(0xFF1B7F5C);
  static const verdeEscuro = Color(0xFF0F5A40);
  static const verdeClaro = Color(0xFFE3F2EC);
  static const laranja = Color(0xFFF28C28);
  static const laranjaClaro = Color(0xFFFFF1E2);
  static const fundo = Color(0xFFF6F8F5);
  static const texto = Color(0xFF1E2A25);
  static const textoSuave = Color(0xFF5E6B65);

  // Cores de situação (as mesmas em todas as telas)
  static const ok = Color(0xFF2E9D5B);
  static const atencao = Color(0xFFE0A100);
  static const critico = Color(0xFFD64545);
  static const neutro = Color(0xFF7A8580);
}

ThemeData temaApp() {
  final esquema = ColorScheme.fromSeed(
    seedColor: Cores.verde,
    primary: Cores.verde,
    secondary: Cores.laranja,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: Cores.fundo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Cores.verde,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Cores.verde,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Cores.verde,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: Cores.verde),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Cores.laranja,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Logo usado no login e no menu lateral.
class LogoApp extends StatelessWidget {
  final double tamanho;
  final bool claro;

  const LogoApp({super.key, this.tamanho = 72, this.claro = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: claro ? Colors.white : Cores.verde,
        borderRadius: BorderRadius.circular(tamanho * 0.28),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.kitchen, size: tamanho * 0.6, color: claro ? Cores.verde : Colors.white),
          Positioned(
            right: tamanho * 0.12,
            bottom: tamanho * 0.12,
            child: Icon(Icons.favorite, size: tamanho * 0.26, color: Cores.laranja),
          ),
        ],
      ),
    );
  }
}
