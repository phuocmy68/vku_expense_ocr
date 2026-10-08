import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: VKUExpenseApp()));
}

class VKUExpenseApp extends StatelessWidget {
  const VKUExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VKU Expense OCR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C4570), // Màu xanh VKU
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
