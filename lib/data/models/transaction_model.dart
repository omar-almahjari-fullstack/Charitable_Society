class TransactionModel {
  final String id;
  final String description;
  final double amount;
  final DateTime createdAt;

  const TransactionModel({required this.id, required this.description, required this.amount, required this.createdAt});
}
