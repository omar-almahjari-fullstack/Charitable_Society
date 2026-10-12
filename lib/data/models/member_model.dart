class MemberModel {
  final String id;
  final String fullName;
  final String phone;
  final String? email;

  const MemberModel({required this.id, required this.fullName, required this.phone, this.email});
}
