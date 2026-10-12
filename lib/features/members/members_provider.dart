import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_cache_service.dart';

// ============================================================
// MEMBER MODEL
// ============================================================
class Member {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? nationalId;
  final String? address;
  final String? profileImageUrl;
  final String? avatarUrl;
  final String? memberNumber;
  final String status;
  final String role;
  final double monthlySubscription;
  final DateTime joinDate;

  Member({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.nationalId,
    this.address,
    this.profileImageUrl,
    this.avatarUrl,
    this.memberNumber,
    this.status = 'active',
    this.role = 'member',
    this.monthlySubscription = 50.0,
    required this.joinDate,
  });

  // ✅ Create from JSON - من قاعدة البيانات
  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      nationalId: json['national_id']?.toString(),
      address: json['address']?.toString(),
      profileImageUrl: json['profile_image_url']?.toString(),
      avatarUrl: json['avatar_url']?.toString() ?? json['profile_image_url']?.toString(),
      memberNumber: json['member_number']?.toString() ?? json['memberNumber']?.toString(),
      status: json['status']?.toString() ?? 'active',
      role: json['role']?.toString() ?? 'member',
      monthlySubscription: (json['monthly_subscription'] ?? 50.0).toDouble(),
      joinDate: json['join_date'] != null
          ? DateTime.parse(json['join_date'].toString())
          : DateTime.now(),
    );
  }

  // ✅ Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'national_id': nationalId,
      'address': address,
      'profile_image_url': profileImageUrl,
      'avatar_url': avatarUrl,
      'member_number': memberNumber,
      'status': status,
      'role': role,
      'monthly_subscription': monthlySubscription,
      'join_date': joinDate.toIso8601String(),
    };
  }

  // ✅ Copy with
  Member copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    String? nationalId,
    String? address,
    String? profileImageUrl,
    String? avatarUrl,
    String? memberNumber,
    String? status,
    String? role,
    double? monthlySubscription,
    DateTime? joinDate,
  }) {
    return Member(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      nationalId: nationalId ?? this.nationalId,
      address: address ?? this.address,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      memberNumber: memberNumber ?? this.memberNumber,
      status: status ?? this.status,
      role: role ?? this.role,
      monthlySubscription: monthlySubscription ?? this.monthlySubscription,
      joinDate: joinDate ?? this.joinDate,
    );
  }

  // ✅ Status helpers
  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';
  bool get isExempt => status == 'exempt';
  bool get isInactive => status == 'inactive';

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'suspended':
        return 'موقوف';
      case 'exempt':
        return 'معفي';
      case 'inactive':
        return 'غير نشط';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'suspended':
        return Colors.orange;
      case 'exempt':
        return Colors.blue;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// ============================================================
// MEMBERS STATE
// ============================================================
class MembersState {
  final List<Member> members;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String selectedFilter;
  final bool hasMore;

  MembersState({
    this.members = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedFilter = 'الكل',
    this.hasMore = true,
  });

  MembersState copyWith({
    List<Member>? members,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? selectedFilter,
    bool? hasMore,
  }) {
    return MembersState(
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  List<Member> get filteredMembers {
    var filtered = members;

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((member) {
        final query = searchQuery.toLowerCase();
        return member.fullName.toLowerCase().contains(query) ||
            member.phone.contains(query) ||
            (member.nationalId?.contains(query) ?? false) ||
            (member.memberNumber?.contains(query) ?? false);
      }).toList();
    }

    // Apply status filter
    if (selectedFilter != 'الكل') {
      final statusMap = {
        'نشط': 'active',
        'موقوف': 'suspended',
        'معفي': 'exempt',
        'غير نشط': 'inactive',
      };
      final status = statusMap[selectedFilter];
      if (status != null) {
        filtered = filtered.where((member) => member.status == status).toList();
      }
    }

    return filtered;
  }
}

// ============================================================
// MEMBERS PROVIDER - ✅ جلب البيانات من Supabase
// ============================================================
class MembersProvider extends StateNotifier<MembersState> {
  MembersProvider() : super(MembersState()) {
    loadMembers();
  }

  // ✅ جلب الأعضاء من Supabase
  Future<void> loadMembers() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // ✅ جلب البيانات من Supabase
      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .order('full_name');

      // ✅ تحويل البيانات إلى List<Member>
      final members = (response as List).map((json) {
        return Member.fromJson(json);
      }).toList();

      state = state.copyWith(
        members: members,
        isLoading: false,
      );

      // حفظ في الكاش لاستعراض الأعضاء دون إنترنت
      try {
        await LocalCacheService.save('cached_members_profiles', response);
      } catch (_) {}
    } catch (e) {
      // استرجاع الأعضاء من الكاش المحلي عند انقطاع الاتصال
      try {
        final cached = await LocalCacheService.get('cached_members_profiles');
        if (cached is List && cached.isNotEmpty) {
          final members = cached.map((json) => Member.fromJson(Map<String, dynamic>.from(json))).toList();
          state = state.copyWith(
            members: members,
            isLoading: false,
          );
          return;
        }
      } catch (_) {}

      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void searchMembers(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  Future<void> refreshMembers() async {
    await loadMembers();
  }

  Future<void> addMember(Member member) async {
    try {
      state = state.copyWith(
        members: [member, ...state.members],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateMember(Member updatedMember) async {
    try {
      final data = {
        'full_name': updatedMember.fullName.trim(),
        'phone': updatedMember.phone.trim(),
        'email': updatedMember.email?.trim().isEmpty ?? true ? null : updatedMember.email?.trim(),
        'national_id': updatedMember.nationalId?.trim().isEmpty ?? true ? null : updatedMember.nationalId?.trim(),
        'address': updatedMember.address?.trim().isEmpty ?? true ? null : updatedMember.address?.trim(),
        'status': updatedMember.status,
        'role': updatedMember.role,
        'monthly_subscription': updatedMember.monthlySubscription,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService.client
          .from('profiles')
          .update(data)
          .eq('id', updatedMember.id);

      await loadMembers();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteMember(String memberId) async {
    try {
      await SupabaseService.client
          .from('profiles')
          .delete()
          .eq('id', memberId);

      await loadMembers();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Member? getMemberById(String id) {
    try {
      return state.members.firstWhere((member) => member.id == id);
    } catch (e) {
      return null;
    }
  }
}

// ============================================================
// PROVIDER INSTANCE
// ============================================================
final membersProvider =
    StateNotifierProvider<MembersProvider, MembersState>((ref) {
  return MembersProvider();
});