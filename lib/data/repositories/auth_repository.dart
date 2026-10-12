import '../models/user_model.dart';

class AuthRepository {
  Future<UserModel> signIn(String email, String password) async {
    return UserModel(id: '1', email: email, role: 'member');
  }
}
