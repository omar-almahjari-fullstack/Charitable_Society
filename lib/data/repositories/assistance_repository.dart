import '../models/assistance_model.dart';

class AssistanceRepository {
  Future<List<AssistanceModel>> fetchAssistance() async {
    return const [
      AssistanceModel(id: '1', memberId: '1', status: 'pending', requestType: 'medical'),
    ];
  }
}
