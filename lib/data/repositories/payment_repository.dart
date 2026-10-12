import '../models/payment_model.dart';

class PaymentRepository {
  Future<List<PaymentModel>> fetchPayments() async {
    return [
      PaymentModel(id: '1', memberId: '1', amount: 100.0, createdAt: DateTime.now()),
    ];
  }
}
