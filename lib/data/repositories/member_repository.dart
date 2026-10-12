import '../models/member_model.dart';

class MemberRepository {
  Future<List<MemberModel>> fetchMembers() async {
    return const [
      MemberModel(id: '1', fullName: 'أحمد بن سليمان', phone: '0500000000'),
      MemberModel(id: '2', fullName: 'سارة القحطاني', phone: '0555555555'),
    ];
  }
}
