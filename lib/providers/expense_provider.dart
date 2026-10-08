import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';
import '../services/database_helper.dart';

class ExpenseNotifier extends StateNotifier<List<ExpenseItem>> {
  ExpenseNotifier() : super([]) {
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    final list = await DatabaseHelper.instance.getAllExpenses();
    state = list;
  }

  Future<void> addExpense(ExpenseItem item) async {
    await DatabaseHelper.instance.insertExpense(item);
    await loadExpenses();
  }

  Future<void> removeExpense(String id) async {
    await DatabaseHelper.instance.deleteExpense(id);
    await loadExpenses();
  }
}

final expenseProvider =
    StateNotifierProvider<ExpenseNotifier, List<ExpenseItem>>((ref) {
  return ExpenseNotifier();
});
