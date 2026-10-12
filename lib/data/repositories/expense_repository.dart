import '../models/expense_model.dart';

class ExpenseRepository {
  Future<List<ExpenseModel>> fetchExpenses() async {
    return [
      ExpenseModel(id: '1', title: 'إيجار', amount: 250.0, createdAt: DateTime.now()),
    ];
  }
}
