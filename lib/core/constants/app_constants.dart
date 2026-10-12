class AppConstants {
  static const String appName = 'جمعية التكافل والتنمية القروية';
  static const String appVersion = '1.0.0';
  
  // Database tables
  static const String profilesTable = 'profiles';
  static const String membersTable = 'members';
  static const String paymentsTable = 'payments';
  static const String paymentCoverageTable = 'payment_coverage';
  static const String expensesTable = 'expenses';
  static const String assistanceRequestsTable = 'assistance_requests';
  static const String financialTransactionsTable = 'financial_transactions';
  static const String notificationsTable = 'notifications';
  static const String announcementsTable = 'announcements';
  static const String auditLogsTable = 'audit_logs';
  static const String settingsTable = 'association_settings';
  
  // Storage buckets
  static const String avatarsBucket = 'avatars';
  static const String receiptsBucket = 'receipts';
  static const String documentsBucket = 'documents';
  static const String associationBucket = 'association';
  static const String reportsBucket = 'reports';
  
  // Payment methods
  static const List<String> paymentMethods = [
    'cash',
    'bank_transfer',
    'cheque',
    'mobile_money',
  ];
  
  static const Map<String, String> paymentMethodLabels = {
    'cash': 'نقدي',
    'bank_transfer': 'تحويل بنكي',
    'cheque': 'شيك',
    'mobile_money': 'تحويل عبر الهاتف',
  };
  
  // Expense categories
  static const List<String> expenseCategories = [
    'assistance',
    'maintenance',
    'electricity',
    'water',
    'salaries',
    'projects',
    'events',
    'administration',
    'other',
  ];
  
  static const Map<String, String> expenseCategoryLabels = {
    'assistance': 'مساعدات',
    'maintenance': 'صيانة',
    'electricity': 'كهرباء',
    'water': 'مياه',
    'salaries': 'رواتب',
    'projects': 'مشاريع',
    'events': 'مناسبات',
    'administration': 'إدارة',
    'other': 'أخرى',
  };
  
  // Assistance types
  static const List<String> assistanceTypes = [
    'medical',
    'educational',
    'emergency',
    'marriage',
    'death',
    'other',
  ];
  
  static const Map<String, String> assistanceTypeLabels = {
    'medical': 'علاجية',
    'educational': 'تعليمية',
    'emergency': 'طارئة',
    'marriage': 'زواج',
    'death': 'وفاة',
    'other': 'أخرى',
  };
}