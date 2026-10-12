class PaymentModel {
  final String id;
  final String memberId;
  final double amount;
  final DateTime createdAt;

  const PaymentModel({required this.id, required this.memberId, required this.amount, required this.createdAt});
}
