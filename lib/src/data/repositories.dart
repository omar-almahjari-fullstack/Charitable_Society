import 'package:supabase_flutter/supabase_flutter.dart';

final db = Supabase.instance.client;

class ProfileRepository {
  Future<Map<String, dynamic>> mine() =>
      db.from('profiles').select().eq('id', db.auth.currentUser!.id).single();
  Future<void> updateMine(Map<String, dynamic> values) =>
      db.from('profiles').update(values).eq('id', db.auth.currentUser!.id);
  Future<List<Map<String, dynamic>>> members({String query = ''}) async {
    var request = db.from('profiles').select().eq('role', 'member');
    if (query.trim().isNotEmpty)
      request = request.or(
        'full_name.ilike.%$query%,phone.ilike.%$query%,national_id.ilike.%$query%',
      );
    final result = await request
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(result);
  }
}

class FinanceRepository {
  Future<Map<String, dynamic>> dashboard() async =>
      await db.rpc('get_dashboard_statistics') as Map<String, dynamic>;
  Future<List<Map<String, dynamic>>> payments() async =>
      List<Map<String, dynamic>>.from(
        await db
            .from('payments')
            .select('*, profiles!payments_member_id_fkey(full_name)')
            .order('created_at', ascending: false),
      );
  Future<void> createPayment({
    required String memberId,
    required double amount,
    required String method,
    String? notes,
  }) => db.rpc(
    'create_payment',
    params: {
      'p_member_id': memberId,
      'p_amount': amount,
      'p_payment_method': method,
      'p_notes': notes,
    },
  );
  Future<List<Map<String, dynamic>>> ledger() async =>
      List<Map<String, dynamic>>.from(
        await db
            .from('financial_transactions')
            .select()
            .order('created_at', ascending: false)
            .limit(100),
      );
}

class AssistanceRepository {
  Future<List<Map<String, dynamic>>> all({required bool admin}) async {
    final result = await db
        .from('assistance_requests')
        .select('*, profiles!assistance_requests_member_id_fkey(full_name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> create({
    required String type,
    required double amount,
    required String description,
  }) => db.from('assistance_requests').insert({
    'member_id': db.auth.currentUser!.id,
    'title': type,
    'requested_amount': amount,
    'description': description,
  });
  Future<void> decide(
    String id, {
    required bool approve,
    double? amount,
    String? reason,
  }) => db.rpc(
    approve ? 'approve_assistance_request' : 'reject_assistance_request',
    params: approve
        ? {'p_request_id': id, 'p_approved_amount': amount}
        : {'p_request_id': id, 'p_rejection_reason': reason},
  );
}
