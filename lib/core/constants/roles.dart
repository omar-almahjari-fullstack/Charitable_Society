enum UserRole {
  member('member'),
  treasurer('treasurer'),
  admin('admin'),
  superAdmin('super_admin');
  
  const UserRole(this.value);
  final String value;
  
  static UserRole fromString(String role) {
    return UserRole.values.firstWhere(
      (e) => e.value == role,
      orElse: () => UserRole.member,
    );
  }
  
  bool get isAdmin => this == UserRole.admin || this == UserRole.superAdmin;
  bool get isTreasurer => this == UserRole.treasurer || isAdmin;
  bool get isSuperAdmin => this == UserRole.superAdmin;
  bool get isMember => this == UserRole.member;
  
  // Permissions
  bool get canManageMembers => this != UserRole.member;
  bool get canManagePayments => this != UserRole.member;
  bool get canManageExpenses => isTreasurer || isAdmin || isSuperAdmin;
  bool get canManageAssistance => isAdmin || isSuperAdmin;
  bool get canManageAnnouncements => isAdmin || isSuperAdmin;
  bool get canViewReports => isTreasurer || isAdmin || isSuperAdmin;
  bool get canManageUsers => isSuperAdmin;
}